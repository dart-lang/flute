# flute

A stipped down Flutter that has all the framework functionality but doesn't render anything. Good for benchmarking various Dart build modes (AOT vs dart2js vs JIT vs debug vs profile vs release...) on various hardware profiles (browser vs desktop vs mobile) such that performance is only affected by the language runtime and not by graphics or any other external systems.
