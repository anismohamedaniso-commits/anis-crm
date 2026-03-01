require('dotenv').config();
const express = require('express');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const OLLAMA = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const API_KEY = process.env.API_KEY || undefined;

app.use(cors());
app.use(express.json({ limit: '2mb' }));

// Simple auth middleware (optional)
function checkAuth(req, res, next) {
  if (!API_KEY) return next();
  const key = req.header('x-api-key') || req.query.api_key;
  if (key !== API_KEY) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

// Forward any model list requests
app.get('/api/ai/models', checkAuth, async (req, res) => {
  try {
    const upstream = await fetch(`${OLLAMA}/api/models`);
    const json = await upstream.json();
    res.json(json);
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// Chat/generate endpoint (forwards to Ollama)
app.post('/api/ai/chat', checkAuth, async (req, res) => {
  try {
    const { model = 'llama2', prompt, messages, options } = req.body || {};
    let constructedPrompt = prompt || '';
    if (!constructedPrompt && Array.isArray(messages)) {
      constructedPrompt = messages.map(m => `${m.role}: ${m.content}`).join('\n\n');
    }

    const upstream = await fetch(`${OLLAMA}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, prompt: constructedPrompt, ...options }),
    });

    // Stream (or plain) proxy: forward content-type and status
    res.status(upstream.status);
    upstream.headers.forEach((v, k) => res.set(k, v));
    const body = await upstream.text();
    res.send(body);
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// Embeddings endpoint (returns JSON)
app.post('/api/ai/embeddings', checkAuth, async (req, res) => {
  try {
    const { model = 'text-embedding-3-small', input } = req.body || {};
    const upstream = await fetch(`${OLLAMA}/api/embeddings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, input }),
    });
    const json = await upstream.json();
    res.json(json);
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

app.listen(PORT, () => console.log(`Ollama proxy listening on http://localhost:${PORT} -> ${OLLAMA}`));