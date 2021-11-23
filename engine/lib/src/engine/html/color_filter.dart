// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:svg' as svg;

import 'package:ui/ui.dart' as ui;

import '../browser_detection.dart';
import '../canvaskit/color_filter.dart';
import '../color_filter.dart';
import '../dom_renderer.dart';
import '../util.dart';
import 'bitmap_canvas.dart';
import 'path_to_svg_clip.dart';
import 'surface.dart';

/// A surface that applies an [ColorFilter] to its children.
class PersistedColorFilter extends PersistedContainerSurface
    implements ui.ColorFilterEngineLayer {
  PersistedColorFilter(PersistedColorFilter? oldLayer, this.filter)
      : super(oldLayer);

  @override
  html.Element? get childContainer => _childContainer;

  /// The dedicated child container element that's separate from the
  /// [rootElement] is used to compensate for the coordinate system shift
  /// introduced by the [rootElement] translation.
  html.Element? _childContainer;

  /// Color filter to apply to this surface.
  final ui.ColorFilter filter;
  html.Element? _filterElement;
  bool containerVisible = true;

  @override
  void adoptElements(PersistedColorFilter oldSurface) {
    super.adoptElements(oldSurface);
    _childContainer = oldSurface._childContainer;
    _filterElement = oldSurface._filterElement;
    oldSurface._childContainer = null;
  }

  @override
  void preroll(PrerollSurfaceContext prerollContext) {
    ++prerollContext.activeColorFilterCount;
    super.preroll(prerollContext);
    --prerollContext.activeColorFilterCount;
  }

  @override
  void discard() {
    super.discard();
    domRenderer.removeResource(_filterElement);
    // Do not detach the child container from the root. It is permanently
    // attached. The elements are reused together and are detached from the DOM
    // together.
    _childContainer = null;
  }

  @override
  html.Element createElement() {
    final html.Element element = defaultCreateElement('flt-color-filter');
    final html.Element container = html.Element.tag('flt-filter-interior');
    container.style.position = 'absolute';
    _childContainer = container;
    element.append(_childContainer!);
    return element;
  }

  @override
  void apply() {
    domRenderer.removeResource(_filterElement);
    _filterElement = null;
    final EngineColorFilter? engineValue = filter as EngineColorFilter?;
    if (engineValue == null) {
      rootElement!.style.backgroundColor = '';
      childContainer?.style.visibility = 'visible';
      return;
    }
    if (engineValue is CkBlendModeColorFilter) {
      _applyBlendModeFilter(engineValue);
    } else if (engineValue is CkMatrixColorFilter) {
      _applyMatrixColorFilter(engineValue);
    } else {
      childContainer?.style.visibility = 'visible';
    }
  }

  void _applyBlendModeFilter(CkBlendModeColorFilter colorFilter) {
    final ui.Color filterColor = colorFilter.color;
    ui.BlendMode colorFilterBlendMode = colorFilter.blendMode;
    final html.CssStyleDeclaration style = childContainer!.style;
    switch (colorFilterBlendMode) {
      case ui.BlendMode.clear:
      case ui.BlendMode.dstOut:
      case ui.BlendMode.srcOut:
        style.visibility = 'hidden';
        return;
      case ui.BlendMode.dst:
      case ui.BlendMode.dstIn:
        // Noop.
        return;
      case ui.BlendMode.src:
      case ui.BlendMode.srcOver:
        // Uses source filter color.
        // Since we don't have a size, we can't use background color.
        // Use svg filter srcIn instead.
        colorFilterBlendMode = ui.BlendMode.srcIn;
        break;
      case ui.BlendMode.dstOver:
      case ui.BlendMode.srcIn:
      case ui.BlendMode.srcATop:
      case ui.BlendMode.dstATop:
      case ui.BlendMode.xor:
      case ui.BlendMode.plus:
      case ui.BlendMode.modulate:
      case ui.BlendMode.screen:
      case ui.BlendMode.overlay:
      case ui.BlendMode.darken:
      case ui.BlendMode.lighten:
      case ui.BlendMode.colorDodge:
      case ui.BlendMode.colorBurn:
      case ui.BlendMode.hardLight:
      case ui.BlendMode.softLight:
      case ui.BlendMode.difference:
      case ui.BlendMode.exclusion:
      case ui.BlendMode.multiply:
      case ui.BlendMode.hue:
      case ui.BlendMode.saturation:
      case ui.BlendMode.color:
      case ui.BlendMode.luminosity:
        break;
    }

    // Use SVG filter for blend mode.
    final SvgFilter svgFilter = svgFilterFromBlendMode(filterColor, colorFilterBlendMode);
    _filterElement = svgFilter.element;
    domRenderer.addResource(_filterElement!);
    style.filter = 'url(#${svgFilter.id})';
    if (colorFilterBlendMode == ui.BlendMode.saturation ||
        colorFilterBlendMode == ui.BlendMode.multiply ||
        colorFilterBlendMode == ui.BlendMode.modulate) {
      style.backgroundColor = colorToCssString(filterColor);
    }
  }

  void _applyMatrixColorFilter(CkMatrixColorFilter colorFilter) {
    final SvgFilter svgFilter = svgFilterFromColorMatrix(colorFilter.matrix);
    _filterElement = svgFilter.element;
    domRenderer.addResource(_filterElement!);
    childContainer!.style.filter = 'url(#${svgFilter.id})';
  }

  @override
  void update(PersistedColorFilter oldSurface) {
    super.update(oldSurface);

    if (oldSurface.filter != filter) {
      apply();
    }
  }
}

SvgFilter svgFilterFromBlendMode(
    ui.Color? filterColor, ui.BlendMode colorFilterBlendMode) {
  final SvgFilter svgFilter;
  switch (colorFilterBlendMode) {
    case ui.BlendMode.srcIn:
    case ui.BlendMode.srcATop:
      svgFilter = _srcInColorFilterToSvg(filterColor);
      break;
    case ui.BlendMode.srcOut:
      svgFilter = _srcOutColorFilterToSvg(filterColor);
      break;
    case ui.BlendMode.dstATop:
      svgFilter = _dstATopColorFilterToSvg(filterColor);
      break;
    case ui.BlendMode.xor:
      svgFilter = _xorColorFilterToSvg(filterColor);
      break;
    case ui.BlendMode.plus:
      // Porter duff source + destination.
      svgFilter = _compositeColorFilterToSvg(filterColor, 0, 1, 1, 0);
      break;
    case ui.BlendMode.modulate:
      // Porter duff source * destination but preserves alpha.
      svgFilter = _modulateColorFilterToSvg(filterColor!);
      break;
    case ui.BlendMode.overlay:
      // Since overlay is the same as hard-light by swapping layers,
      // pass hard-light blend function.
      svgFilter = _blendColorFilterToSvg(
        filterColor,
        blendModeToSvgEnum(ui.BlendMode.hardLight)!,
        swapLayers: true,
      );
      break;
    // Several of the filters below (although supported) do not render the
    // same (close but not exact) as native flutter when used as blend mode
    // for a background-image with a background color. They only look
    // identical when feBlend is used within an svg filter definition.
    //
    // Saturation filter uses destination when source is transparent.
    // cMax = math.max(r, math.max(b, g));
    // cMin = math.min(r, math.min(b, g));
    // delta = cMax - cMin;
    // lightness = (cMax + cMin) / 2.0;
    // saturation = delta / (1.0 - (2 * lightness - 1.0).abs());
    case ui.BlendMode.saturation:
    case ui.BlendMode.colorDodge:
    case ui.BlendMode.colorBurn:
    case ui.BlendMode.hue:
    case ui.BlendMode.color:
    case ui.BlendMode.luminosity:
    case ui.BlendMode.multiply:
    case ui.BlendMode.screen:
    case ui.BlendMode.darken:
    case ui.BlendMode.lighten:
    case ui.BlendMode.hardLight:
    case ui.BlendMode.softLight:
    case ui.BlendMode.difference:
    case ui.BlendMode.exclusion:
      svgFilter = _blendColorFilterToSvg(
          filterColor, blendModeToSvgEnum(colorFilterBlendMode)!);
      break;
    case ui.BlendMode.src:
    case ui.BlendMode.dst:
    case ui.BlendMode.dstIn:
    case ui.BlendMode.dstOut:
    case ui.BlendMode.dstOver:
    case ui.BlendMode.clear:
    case ui.BlendMode.srcOver:
      throw UnimplementedError(
        'Blend mode not supported in HTML renderer: $colorFilterBlendMode',
      );
  }
  return svgFilter;
}

// See: https://www.w3.org/TR/SVG11/types.html#InterfaceSVGUnitTypes
const int kObjectBoundingBox = 2;

// See: https://www.w3.org/TR/SVG11/filters.html#InterfaceSVGFEColorMatrixElement
const int kMatrixType = 1;

// See: https://www.w3.org/TR/SVG11/filters.html#InterfaceSVGFECompositeElement
const int kOperatorOut = 3;
const int kOperatorAtop = 4;
const int kOperatorXor = 5;
const int kOperatorArithmetic = 6;

/// Builds an [SvgFilter].
class SvgFilterBuilder {
  static int _filterIdCounter = 0;

  SvgFilterBuilder() : id = '_fcf${++_filterIdCounter}' {
    filter.id = id;

    // SVG filters that contain `<feImage>` will fail on several browsers
    // (e.g. Firefox) if bounds are not specified.
    filter.filterUnits!.baseVal = kObjectBoundingBox;

    // On Firefox percentage width/height 100% works however fails in Chrome 88.
    filter.x!.baseVal!.valueAsString = '0%';
    filter.y!.baseVal!.valueAsString = '0%';
    filter.width!.baseVal!.valueAsString = '100%';
    filter.height!.baseVal!.valueAsString = '100%';
  }

  final String id;
  final svg.SvgSvgElement root = kSvgResourceHeader.clone(false) as svg.SvgSvgElement;
  final svg.FilterElement filter = svg.FilterElement();

  set colorInterpolationFilters(String filters) {
    filter.setAttribute('color-interpolation-filters', filters);
  }

  void setFeColorMatrix(List<double> matrix, { required String result }) {
    final svg.FEColorMatrixElement element = svg.FEColorMatrixElement();
    element.type!.baseVal = kMatrixType;
    element.result!.baseVal = result;
    final svg.NumberList value = element.values!.baseVal!;
    for (int i = 0; i < matrix.length; i++) {
      value.appendItem(root.createSvgNumber()..value = matrix[i]);
    }
    filter.append(element);
  }

  void setFeFlood({
    required String floodColor,
    required String floodOpacity,
    required String result,
  }) {
    final svg.FEFloodElement element = svg.FEFloodElement();
    element.setAttribute('flood-color', floodColor);
    element.setAttribute('flood-opacity', floodOpacity);
    element.result!.baseVal = result;
    filter.append(element);
  }

  void setFeBlend({
    required String in1,
    required String in2,
    required int mode,
  }) {
    final svg.FEBlendElement element = svg.FEBlendElement();
    element.in1!.baseVal = in1;
    element.in2!.baseVal = in2;
    element.mode!.baseVal = mode;
    filter.append(element);
  }

  void setFeComposite({
    required String in1,
    required String in2,
    required int operator,
    num? k1,
    num? k2,
    num? k3,
    num? k4,
    required String result,
  }) {
    final svg.FECompositeElement element = svg.SvgElement.tag('feComposite') as svg.FECompositeElement;
    element.in1!.baseVal = in1;
    element.in2!.baseVal = in2;
    element.operator!.baseVal = operator;
    if (k1 != null) {
      element.k1!.baseVal = k1;
    }
    if (k2 != null) {
      element.k2!.baseVal = k2;
    }
    if (k3 != null) {
      element.k3!.baseVal = k3;
    }
    if (k4 != null) {
      element.k4!.baseVal = k4;
    }
    element.result!.baseVal = result;
    filter.append(element);
  }

  void setFeImage({
    required String href,
    required String result,
    required double width,
    required double height,
  }) {
    final svg.FEImageElement element = svg.FEImageElement();
    element.href!.baseVal = href;
    element.result!.baseVal = result;

    // WebKit will not render if x/y/width/height is specified. So we return
    // explicit size here unless running on WebKit.
    if (browserEngine != BrowserEngine.webkit) {
      element.x!.baseVal!.newValueSpecifiedUnits(svg.Length.SVG_LENGTHTYPE_NUMBER, 0);
      element.y!.baseVal!.newValueSpecifiedUnits(svg.Length.SVG_LENGTHTYPE_NUMBER, 0);
      element.width!.baseVal!.newValueSpecifiedUnits(svg.Length.SVG_LENGTHTYPE_NUMBER, width);
      element.height!.baseVal!.newValueSpecifiedUnits(svg.Length.SVG_LENGTHTYPE_NUMBER, height);
    }
    filter.append(element);
  }

  SvgFilter build() {
    root.append(filter);
    return SvgFilter._(id, root);
  }
}

class SvgFilter {
  SvgFilter._(this.id, this.element);

  final String id;
  final svg.SvgSvgElement element;
}

SvgFilter svgFilterFromColorMatrix(List<double> matrix) {
  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.setFeColorMatrix(matrix, result: 'comp');
  return builder.build();
}

// The color matrix for feColorMatrix element changes colors based on
// the following:
//
// | R' |     | r1 r2 r3 r4 r5 |   | R |
// | G' |     | g1 g2 g3 g4 g5 |   | G |
// | B' |  =  | b1 b2 b3 b4 b5 | * | B |
// | A' |     | a1 a2 a3 a4 a5 |   | A |
// | 1  |     | 0  0  0  0  1  |   | 1 |
//
// R' = r1*R + r2*G + r3*B + r4*A + r5
// G' = g1*R + g2*G + g3*B + g4*A + g5
// B' = b1*R + b2*G + b3*B + b4*A + b5
// A' = a1*R + a2*G + a3*B + a4*A + a5
SvgFilter _srcInColorFilterToSvg(ui.Color? color) {
  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.colorInterpolationFilters = 'sRGB';
  builder.setFeColorMatrix(
    const <double>[
      0, 0, 0, 0, 1,
      0, 0, 0, 0, 1,
      0, 0, 0, 0, 1,
      0, 0, 0, 1, 0,
    ],
    result: 'destalpha',
  );
  builder.setFeFlood(
    floodColor: colorToCssString(color) ?? '',
    floodOpacity: '1',
    result: 'flood',
  );
  builder.setFeComposite(
    in1: 'flood',
    in2: 'destalpha',
    operator: kOperatorArithmetic,
    k1: 1,
    k2: 0,
    k3: 0,
    k4: 0,
    result: 'comp',
  );
  return builder.build();
}

/// The destination that overlaps the source is composited with the source and
/// replaces the destination. dst-atop	CR = CB*αB*αA+CA*αA*(1-αB)	αR=αA
SvgFilter _dstATopColorFilterToSvg(ui.Color? color) {
  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.setFeFlood(
    floodColor: colorToCssString(color) ?? '',
    floodOpacity: '1',
    result: 'flood',
  );
  builder.setFeComposite(
    in1: 'SourceGraphic',
    in2: 'flood',
    operator: kOperatorAtop,
    result: 'comp',
  );
  return builder.build();
}

SvgFilter _srcOutColorFilterToSvg(ui.Color? color) {
  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.setFeFlood(
    floodColor: colorToCssString(color) ?? '',
    floodOpacity: '1',
    result: 'flood',
  );
  builder.setFeComposite(
    in1: 'flood',
    in2: 'SourceGraphic',
    operator: kOperatorOut,
    result: 'comp',
  );
  return builder.build();
}

SvgFilter _xorColorFilterToSvg(ui.Color? color) {
  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.setFeFlood(
    floodColor: colorToCssString(color) ?? '',
    floodOpacity: '1',
    result: 'flood',
  );
  builder.setFeComposite(
    in1: 'flood',
    in2: 'SourceGraphic',
    operator: kOperatorXor,
    result: 'comp',
  );
  return builder.build();
}

// The source image and color are composited using :
// result = k1 *in*in2 + k2*in + k3*in2 + k4.
SvgFilter _compositeColorFilterToSvg(
    ui.Color? color, double k1, double k2, double k3, double k4) {
  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.setFeFlood(
    floodColor: colorToCssString(color) ?? '',
    floodOpacity: '1',
    result: 'flood',
  );
  builder.setFeComposite(
    in1: 'flood',
    in2: 'SourceGraphic',
    operator: kOperatorArithmetic,
    k1: k1,
    k2: k2,
    k3: k3,
    k4: k4,
    result: 'comp',
  );
  return builder.build();
}

// Porter duff source * destination , keep source alpha.
// First apply color filter to source to change it to [color], then
// composite using multiplication.
SvgFilter _modulateColorFilterToSvg(ui.Color color) {
  final double r = color.red / 255.0;
  final double b = color.blue / 255.0;
  final double g = color.green / 255.0;

  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.setFeColorMatrix(
    <double>[
      0, 0, 0, 0, r,
      0, 0, 0, 0, g,
      0, 0, 0, 0, b,
      0, 0, 0, 1, 0,
    ],
    result: 'recolor',
  );
  builder.setFeComposite(
    in1: 'recolor',
    in2: 'SourceGraphic',
    operator: kOperatorArithmetic,
    k1: 1,
    k2: 0,
    k3: 0,
    k4: 0,
    result: 'comp',
  );
  return builder.build();
}

// Uses feBlend element to blend source image with a color.
SvgFilter _blendColorFilterToSvg(ui.Color? color, SvgBlendMode svgBlendMode,
    {bool swapLayers = false}) {
  final SvgFilterBuilder builder = SvgFilterBuilder();
  builder.setFeFlood(
    floodColor: colorToCssString(color) ?? '',
    floodOpacity: '1',
    result: 'flood',
  );
  if (swapLayers) {
    builder.setFeBlend(
      in1: 'SourceGraphic',
      in2: 'flood',
      mode: svgBlendMode.blendMode,
    );
  } else {
    builder.setFeBlend(
      in1: 'flood',
      in2: 'SourceGraphic',
      mode: svgBlendMode.blendMode,
    );
  }
  return builder.build();
}
