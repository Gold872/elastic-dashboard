if (typeof ImageDecoder === "undefined") {
  // Enables WASM to run in environments that don't support ImageDecoder
  // Notably, this allows it to run in insecure contexts like on a robot
  window.ImageDecoder = () => {};
}
// prettier-ignore
{{flutter_js}}
// prettier-ignore
{{flutter_build_config}}

_flutter.buildConfig.useLocalCanvasKit = true;
_flutter.loader.load({ renderer: "skwasm" });
