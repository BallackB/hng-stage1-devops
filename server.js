const http = require("http");

const PORT = process.env.PORT || 80;

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Hello from HNG DevOps Stage 1!\n");
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
