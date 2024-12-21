const express = require('express');
const app = express();
const port = 3000;

// Thêm middleware CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

app.use(express.json());

let messages = [];

app.get('/messages', (req, res) => {
  res.json(messages);
});

app.post('/messages', (req, res) => {
  const message = {
    id: Date.now().toString(),
    content: req.body.content,
    timestamp: req.body.timestamp
  };
  messages.push(message);
  res.json(message);
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
}); 