'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "8d7bcfdcddd3d9aa604a720b61a8c022",
"assets/AssetManifest.bin.json": "e9dd14d547ffa6fb1d838d3887ddf5fe",
"assets/AssetManifest.json": "8375ae9641ea1ac5b90330bc540e2865",
"assets/assets/fields/2018-field.png": "21afb796f0122d5b152c72979403a40e",
"assets/assets/fields/2018-powerup.json": "d6b4c1a0e7820076609c4283fc9034a1",
"assets/assets/fields/2019-deepspace.json": "11dfc289367d9121ba2ebaf34efe2465",
"assets/assets/fields/2019-field.png": "9ef606c0c48d66fd9bf1bb03fcdb91b0",
"assets/assets/fields/2020-field.png": "e2bf9f953afab2e84e6b9ce501bd52c5",
"assets/assets/fields/2020-infiniterecharge.json": "efa5e9f10c1b00b66b1fcf4b86315bff",
"assets/assets/fields/2022-field.png": "14bcc74ac026758f3d665172d949697a",
"assets/assets/fields/2022-rapidreact.json": "d6db429dca42f2bb0f91f916d0961a33",
"assets/assets/fields/2023-chargedup.json": "568bf61d5429ef2ff8d3a3f9ade482c9",
"assets/assets/fields/2023-field.png": "af9e83f77bbc80f407d3702764d1a5e7",
"assets/assets/fields/2024-crescendo.json": "56a8753eece373598f79bda2c164e3bc",
"assets/assets/fields/2024-field.png": "c15f644074b28352513facd8167835fc",
"assets/assets/logos/logo.png": "94c41d677b8be2d88257e7c371170df1",
"assets/assets/logos/logo_full.png": "3e8463d445abfa3bfed840d0cfee1cc3",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/fonts/MaterialIcons-Regular.otf": "1d841a588229a71bb6ea72e09bad6af2",
"assets/NOTICES": "edeb861c4eb385e6aa70327f17e248f8",
"assets/packages/titlebar_buttons/assets/themes/adwaita/close-active.svg": "3a073e2349af7701b12708a74a685f82",
"assets/packages/titlebar_buttons/assets/themes/adwaita/close-hover.svg": "9a7b6ca37751496dd4faa6b5c6e44344",
"assets/packages/titlebar_buttons/assets/themes/adwaita/close.svg": "495858da9474f76e1e55eac0813e96c2",
"assets/packages/titlebar_buttons/assets/themes/adwaita/maximize-active.svg": "fdaf450b8fce1de545e91fcdaa54f4e3",
"assets/packages/titlebar_buttons/assets/themes/adwaita/maximize-hover.svg": "153a3b771f482ca852fc5db94e272c53",
"assets/packages/titlebar_buttons/assets/themes/adwaita/maximize.svg": "eca509988316e7020433935a4f748821",
"assets/packages/titlebar_buttons/assets/themes/adwaita/minimize-active.svg": "5148b7558428d30741fb2102b61d0090",
"assets/packages/titlebar_buttons/assets/themes/adwaita/minimize-hover.svg": "611539ab0eaae0a05309cadd087d9fb6",
"assets/packages/titlebar_buttons/assets/themes/adwaita/minimize.svg": "e434e115af18b857498b404e70c0c588",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/close-active.svg": "e681b1b706c7858a06d0e7be83f5bffc",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/close-hover.svg": "a76ebe248cfbd18b25e6b24db0c97d93",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/close.svg": "60df3479d5f36f99327c0e91d7f7f6a1",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/maximize-active.svg": "7abea8d54af60af9c8539b76603aa6e5",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/maximize-hover.svg": "56953703d7329d18388d8bc143fc787c",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/maximize.svg": "731a7b0a424f120d7603072c91b97d7e",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/minimize-active.svg": "2435c5211fa9ec6dfdd58560a1e10608",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/minimize-hover.svg": "5f9a3aeb2fda576cb33b3f569f471795",
"assets/packages/titlebar_buttons/assets/themes/arc-dark/minimize.svg": "f01942f9a5e0716d63826c0f6e60bb3c",
"assets/packages/titlebar_buttons/assets/themes/arc-light/close-active.svg": "2e1bbc4f106655b6fb8324329bdb4454",
"assets/packages/titlebar_buttons/assets/themes/arc-light/close-hover.svg": "5ec07421ed79dd216254ab0d079402a5",
"assets/packages/titlebar_buttons/assets/themes/arc-light/close.svg": "acf12ad5a7681226e8886bfb820c4fd9",
"assets/packages/titlebar_buttons/assets/themes/arc-light/maximize-active.svg": "7abea8d54af60af9c8539b76603aa6e5",
"assets/packages/titlebar_buttons/assets/themes/arc-light/maximize-hover.svg": "8662d3562d78888c07e0c87d2e0a7716",
"assets/packages/titlebar_buttons/assets/themes/arc-light/maximize.svg": "2af431cea3540e99332393f6db520d4b",
"assets/packages/titlebar_buttons/assets/themes/arc-light/minimize-active.svg": "2435c5211fa9ec6dfdd58560a1e10608",
"assets/packages/titlebar_buttons/assets/themes/arc-light/minimize-hover.svg": "e2d7d314918f368ce8b53ca1628aa342",
"assets/packages/titlebar_buttons/assets/themes/arc-light/minimize.svg": "d199f48a392a12726f038698ba3f8c0f",
"assets/packages/titlebar_buttons/assets/themes/breeze/close-active.svg": "3200eab6937fab0055ee9b7e9a5587bb",
"assets/packages/titlebar_buttons/assets/themes/breeze/close-hover.svg": "2bea2ace565b419b72b3e6120db3cd21",
"assets/packages/titlebar_buttons/assets/themes/breeze/close.svg": "336b4edede351a886522ad9fa341a338",
"assets/packages/titlebar_buttons/assets/themes/breeze/maximize-active.svg": "150ef2dbac77270f6f7dda2503edadfe",
"assets/packages/titlebar_buttons/assets/themes/breeze/maximize-hover.svg": "52a77c2d238fc4d826b6d0c114999fcb",
"assets/packages/titlebar_buttons/assets/themes/breeze/maximize.svg": "38ea0310e127a1b0800c0cdb5c163f77",
"assets/packages/titlebar_buttons/assets/themes/breeze/minimize-active.svg": "c1da68a49406dee102800216459e96a7",
"assets/packages/titlebar_buttons/assets/themes/breeze/minimize-hover.svg": "7f5bb55e1fb0f9a71b1df5cee14a51aa",
"assets/packages/titlebar_buttons/assets/themes/breeze/minimize.svg": "18366daa6cccaf370daf49311c01655b",
"assets/packages/titlebar_buttons/assets/themes/elementary/close.svg": "738da940ef6d978aab28afa3f590a721",
"assets/packages/titlebar_buttons/assets/themes/elementary/maximize.svg": "3eca4448fa1c753eee82a0a20e7ea89c",
"assets/packages/titlebar_buttons/assets/themes/elementary/minimize.svg": "1cfa1dc42a3421ef6649e49c8af5d006",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/close-active.svg": "0d4339008871c8486e7fec0edf4f557b",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/close-hover.svg": "0d4339008871c8486e7fec0edf4f557b",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/close.svg": "c43a377d111df1e1d2f37a231898865e",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/maximize-active.svg": "bd9e3dfe1fd4bfdfff8283f9994f4754",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/maximize-hover.svg": "bd9e3dfe1fd4bfdfff8283f9994f4754",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/maximize.svg": "b2281965f7e04c8c7cb340d8345e0fe2",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/minimize-active.svg": "f0fd64817e4534eb5c77429d474563d2",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/minimize-hover.svg": "f0fd64817e4534eb5c77429d474563d2",
"assets/packages/titlebar_buttons/assets/themes/flat-remix/minimize.svg": "e5955a935f9b37739530e523ae5cc281",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/close-active.svg": "9fb4fe9bffc7f4e34e1fdecdd146b04f",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/close-hover.svg": "6e805c26d527b9e5fa28e0936e4b4fb6",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/close.svg": "85d9057dc05198bbc605ae41339d3f4b",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/maximize-active.svg": "fc327ee664e9f5661d1131b53563e6a6",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/maximize-hover.svg": "6400b61acc2790ad864726b9c2ae2949",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/maximize.svg": "663f0a4137258f2c40e64667a7b0d1ea",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/minimize-active.svg": "7fcdfaf115b2f31cf16f4bf0193b72fe",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/minimize-hover.svg": "7c44633fd1dde56acfc0004cfe6eecee",
"assets/packages/titlebar_buttons/assets/themes/materia-dark/minimize.svg": "d47bd0e7a3c25e6baf902e1ed58b6066",
"assets/packages/titlebar_buttons/assets/themes/materia-light/close-active.svg": "a3c469f069dfc1358698dcbf9ef2adcb",
"assets/packages/titlebar_buttons/assets/themes/materia-light/close-hover.svg": "9046ac30748b622fbbe6d43a4e3f1900",
"assets/packages/titlebar_buttons/assets/themes/materia-light/close.svg": "51c5a252f944a641c41d2a6557236129",
"assets/packages/titlebar_buttons/assets/themes/materia-light/maximize-active.svg": "84deb05781da6d357b9ae7280d558d2a",
"assets/packages/titlebar_buttons/assets/themes/materia-light/maximize-hover.svg": "606be773a7c7ac153b5e2eb2de665b84",
"assets/packages/titlebar_buttons/assets/themes/materia-light/maximize.svg": "e7ee6348d44133aff1023d9f6d5d4f05",
"assets/packages/titlebar_buttons/assets/themes/materia-light/minimize-active.svg": "7c9182f6e1166c320152ceb7090dd106",
"assets/packages/titlebar_buttons/assets/themes/materia-light/minimize-hover.svg": "58b829cac511a81264297397f41669d6",
"assets/packages/titlebar_buttons/assets/themes/materia-light/minimize.svg": "1adbd20e9f6ac10a2d5e52d4eddb4e4b",
"assets/packages/titlebar_buttons/assets/themes/nordic/close-active.svg": "fa0dbc9f70651980a723ded6a51e3d89",
"assets/packages/titlebar_buttons/assets/themes/nordic/close-hover.svg": "e379147e3b002b65b52f065f5475f018",
"assets/packages/titlebar_buttons/assets/themes/nordic/close.svg": "100d0f49953721d16bd9b30bbbdc0706",
"assets/packages/titlebar_buttons/assets/themes/nordic/maximize-active.svg": "c4ef0521818dbc41ae019db685b27fb4",
"assets/packages/titlebar_buttons/assets/themes/nordic/maximize-hover.svg": "69f52365b38cedcf0cbd559599ee4309",
"assets/packages/titlebar_buttons/assets/themes/nordic/maximize.svg": "08f662d88e4fd59a540285d78387e087",
"assets/packages/titlebar_buttons/assets/themes/nordic/minimize-active.svg": "b50eaba2d557c5d11c41a315c496f1dd",
"assets/packages/titlebar_buttons/assets/themes/nordic/minimize-hover.svg": "1a2d3d6635a522bb3a68c21ece907b41",
"assets/packages/titlebar_buttons/assets/themes/nordic/minimize.svg": "6d3a5c751e085386a932c4f41a0bdefd",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/close-active.svg": "82d218a05559635ce45bcec48897e799",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/close-hover.svg": "82d218a05559635ce45bcec48897e799",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/close.svg": "2fe2d234adbc2b42e07dbe61670eeca6",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/maximize-active.svg": "b2db20bb0bcc84fde9fe3274c1e07e7a",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/maximize-hover.svg": "b2db20bb0bcc84fde9fe3274c1e07e7a",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/maximize.svg": "0015ddb1a8e73c53ee476ce2e9c7c267",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/minimize-active.svg": "f78c2ba47d388d2dde5a9bdb0d46817c",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/minimize-hover.svg": "f78c2ba47d388d2dde5a9bdb0d46817c",
"assets/packages/titlebar_buttons/assets/themes/osx-arc/minimize.svg": "e0b223a27980f3d44b3c988da551ccfc",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/close-active.svg": "c3df3141f42764e1f10d13f7d30e902f",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/close-hover.svg": "1f652b81f9d2ee6ce59701a3ffbacd88",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/close.svg": "7a6960fa637cff15962284d87efc57e0",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/maximize-active.svg": "7c7509958c47b71ce5fc3a02ec492154",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/maximize-hover.svg": "4b8e501a0151db9aa10edf4978c213af",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/maximize.svg": "fcec63844e30fa683574c06f333385c6",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/minimize-active.svg": "26567950c62adb2db1199fb3e96faf8d",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/minimize-hover.svg": "771267bf43da2dc6f7b4a6a07345e1b1",
"assets/packages/titlebar_buttons/assets/themes/pop-dark/minimize.svg": "100f400ffab7ba2dc422a0031ddcfd27",
"assets/packages/titlebar_buttons/assets/themes/pop-light/close-active.svg": "c3df3141f42764e1f10d13f7d30e902f",
"assets/packages/titlebar_buttons/assets/themes/pop-light/close-hover.svg": "1f652b81f9d2ee6ce59701a3ffbacd88",
"assets/packages/titlebar_buttons/assets/themes/pop-light/close.svg": "7a6960fa637cff15962284d87efc57e0",
"assets/packages/titlebar_buttons/assets/themes/pop-light/maximize-active.svg": "fdb9e08b89fdff15ec9ea0d89d03be68",
"assets/packages/titlebar_buttons/assets/themes/pop-light/maximize-hover.svg": "03a2b38b819bdbfb464ae0b76d815b48",
"assets/packages/titlebar_buttons/assets/themes/pop-light/maximize.svg": "0836a19c0884e08f6ec9b7b794d83c66",
"assets/packages/titlebar_buttons/assets/themes/pop-light/minimize-active.svg": "c57ce6e4efccd202303b6b1fe75e3a1e",
"assets/packages/titlebar_buttons/assets/themes/pop-light/minimize-hover.svg": "487569a041eaff47a9f1a91c10176f5e",
"assets/packages/titlebar_buttons/assets/themes/pop-light/minimize.svg": "0bd8e94b94f023b96f9bf35097e0e97d",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/close-active.svg": "d514da507d69229ff03fba9ba4c8fc84",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/close-hover.svg": "124c659827868fe173f46231a0dd3532",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/close.svg": "8b839fe22d55828ba3f2662bda7bddb4",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/maximize-active.svg": "d1018320f58c656a54f7c62c31543e20",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/maximize-hover.svg": "0d48c3018a70330467190156bd7d1858",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/maximize.svg": "10d075c84ca40947d8f3b29fc377b0da",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/minimize-active.svg": "7a670ccd56f5987d2e64f360c5b7cfad",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/minimize-hover.svg": "5d6e49370bb6292a3a7e68108c2b6ccf",
"assets/packages/titlebar_buttons/assets/themes/unity-dark/minimize.svg": "1882cecb367d85f1c1a1aefb72f32d9b",
"assets/packages/titlebar_buttons/assets/themes/unity-light/close-active.svg": "d514da507d69229ff03fba9ba4c8fc84",
"assets/packages/titlebar_buttons/assets/themes/unity-light/close-hover.svg": "124c659827868fe173f46231a0dd3532",
"assets/packages/titlebar_buttons/assets/themes/unity-light/close.svg": "8b839fe22d55828ba3f2662bda7bddb4",
"assets/packages/titlebar_buttons/assets/themes/unity-light/maximize-active.svg": "4e318181d326ed3d46c2bd275d731822",
"assets/packages/titlebar_buttons/assets/themes/unity-light/maximize-hover.svg": "ac94ce4278ecba44d82e821f772441a7",
"assets/packages/titlebar_buttons/assets/themes/unity-light/maximize.svg": "8f73064c5a5c0caadcd00de8aa1b35bb",
"assets/packages/titlebar_buttons/assets/themes/unity-light/minimize-active.svg": "10a2331f51c242c18db21f68d2811935",
"assets/packages/titlebar_buttons/assets/themes/unity-light/minimize-hover.svg": "c1d705cf06c78e41ce5fcd5a1cbb9f84",
"assets/packages/titlebar_buttons/assets/themes/unity-light/minimize.svg": "dab67e9848c795621a8ce967c22160a9",
"assets/packages/titlebar_buttons/assets/themes/vimix/close-active.svg": "8638ec609362fdd99ca5ab0d11bf37de",
"assets/packages/titlebar_buttons/assets/themes/vimix/close-hover.svg": "e696ec5a29731115a226099d6cfccc4f",
"assets/packages/titlebar_buttons/assets/themes/vimix/close.svg": "85bf50fb57d965880d0e945845102831",
"assets/packages/titlebar_buttons/assets/themes/vimix/maximize-active.svg": "fba2a6ae55febaf1c35ab3556aa207d8",
"assets/packages/titlebar_buttons/assets/themes/vimix/maximize-hover.svg": "de8913dcd654f8661699c3a2da307b0a",
"assets/packages/titlebar_buttons/assets/themes/vimix/maximize.svg": "804d68402ac8659f97996e0c9494e68b",
"assets/packages/titlebar_buttons/assets/themes/vimix/minimize-active.svg": "1d9571dab6cc38bc64336a2162921442",
"assets/packages/titlebar_buttons/assets/themes/vimix/minimize-hover.svg": "76a7ce5f21af44addd142610373beed5",
"assets/packages/titlebar_buttons/assets/themes/vimix/minimize.svg": "af14426de6839b83c640f872eda23b52",
"assets/packages/titlebar_buttons/assets/themes/yaru/close-active.svg": "cf8f7ec63162a2a35b44523d738aedff",
"assets/packages/titlebar_buttons/assets/themes/yaru/close-hover.svg": "d2041c2890f5f85f694a521db7ea6e6e",
"assets/packages/titlebar_buttons/assets/themes/yaru/close.svg": "8ff63df0a22e9b7dd536a0d5d0c83925",
"assets/packages/titlebar_buttons/assets/themes/yaru/maximize-active.svg": "9b3c8b210dcff3ca65b5aaf277ae2cf1",
"assets/packages/titlebar_buttons/assets/themes/yaru/maximize-hover.svg": "a466339be81e009a4a75f0e1f3c15b53",
"assets/packages/titlebar_buttons/assets/themes/yaru/maximize.svg": "dac8806e404397bfe3f45fbf245bc62d",
"assets/packages/titlebar_buttons/assets/themes/yaru/minimize-active.svg": "66a4aeedd2717f10e3eb75705ab356c5",
"assets/packages/titlebar_buttons/assets/themes/yaru/minimize-hover.svg": "e86f9232cfc405852e1cc35474475c8e",
"assets/packages/titlebar_buttons/assets/themes/yaru/minimize.svg": "eb1190735d11f3bb79932c81406bd8d4",
"assets/packages/window_manager/images/ic_chrome_close.png": "75f4b8ab3608a05461a31fc18d6b47c2",
"assets/packages/window_manager/images/ic_chrome_maximize.png": "af7499d7657c8b69d23b85156b60298c",
"assets/packages/window_manager/images/ic_chrome_minimize.png": "4282cd84cb36edf2efb950ad9269ca62",
"assets/packages/window_manager/images/ic_chrome_unmaximize.png": "4a90c1909cb74e8f0d35794e2f61d8bf",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "738255d00768497e86aa4ca510cce1e1",
"canvaskit/canvaskit.js.symbols": "74a84c23f5ada42fe063514c587968c6",
"canvaskit/canvaskit.wasm": "9251bb81ae8464c4df3b072f84aa969b",
"canvaskit/chromium/canvaskit.js": "901bb9e28fac643b7da75ecfd3339f3f",
"canvaskit/chromium/canvaskit.js.symbols": "ee7e331f7f5bbf5ec937737542112372",
"canvaskit/chromium/canvaskit.wasm": "399e2344480862e2dfa26f12fa5891d7",
"canvaskit/skwasm.js": "5d4f9263ec93efeb022bb14a3881d240",
"canvaskit/skwasm.js.symbols": "c3c05bd50bdf59da8626bbe446ce65a3",
"canvaskit/skwasm.wasm": "4051bfc27ba29bf420d17aa0c3a98bce",
"canvaskit/skwasm.worker.js": "bfb704a6c714a75da9ef320991e88b03",
"favicon.png": "145a65902344734dd283bdee9c8ba442",
"flutter.js": "383e55f7f3cce5be08fcf1f3881f585c",
"flutter_bootstrap.js": "34711f038ca5da976edac3bbc9037add",
"icons/Icon-192.png": "f24813392d1641d8c4ff691e1574723d",
"icons/Icon-512.png": "4fb71426210c8b08edbf30dc154e6c7f",
"icons/Icon-maskable-192.png": "f24813392d1641d8c4ff691e1574723d",
"icons/Icon-maskable-512.png": "4fb71426210c8b08edbf30dc154e6c7f",
"index.html": "8388017c976bc05419c3ea22ada111ef",
"/": "8388017c976bc05419c3ea22ada111ef",
"main.dart.js": "5da53492a1f485b86577a56b75a4b9c7",
"manifest.json": "6ccedc267e8597ea5eefedc91b7d3286",
"version.json": "867b1e6bc7096727c170b4394332e685"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
