// If you want to use Phoenix channels, run `mix help phx.gen.channel` to get started and then uncomment the line below.
// import "./user_socket.js"

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken
  }
});

// Connect if there are any LiveViews on the page
liveSocket.connect();

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
