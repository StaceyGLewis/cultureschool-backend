const WebSocket = require('ws');

let wss;

function setupWebSocket(server) {
  // ✅ Add explicit path for Render routing
  wss = new WebSocket.Server({ server, path: "/ws" });

  wss.on('connection', (ws) => {
    console.log('🔌 WebSocket client connected');

    ws.on('message', (data) => {
      try {
        const parsed = JSON.parse(data);
        console.log('📩 Valid WebSocket Message:', parsed);
        broadcastExceptSender(ws, JSON.stringify(parsed));
      } catch (err) {
        console.error("❌ Invalid JSON from WebSocket:", data);
      }
    });

    ws.on('close', () => {
      console.log('❌ WebSocket client disconnected');
    });
  });
}

function broadcastExceptSender(sender, message) {
  if (!wss) return;
  wss.clients.forEach((client) => {
    if (client !== sender && client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

module.exports = setupWebSocket;
