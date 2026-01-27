import axios from "axios";
import * as fs from "fs";
import * as path from "path";

// --- Configuration ---
const MAX_RETRIES = 5;
const RETRY_DELAY_MS = 5000; // 5 seconds
// Simple file-based queue for persistence across restarts
const QUEUE_FILE = path.join(__dirname, "../../webhook_queue.json");

interface WebhookJob {
  id: string;
  url: string;
  payload: any;
  headers?: any;
  attempts: number;
  timestamp: string;
}

// In-memory queue (loaded from file on startup)
let queue: WebhookJob[] = [];

// --- Persistence Helpers ---
const loadQueue = () => {
  try {
    if (fs.existsSync(QUEUE_FILE)) {
      const data = fs.readFileSync(QUEUE_FILE, "utf-8");
      queue = JSON.parse(data);
      console.log(
        `[WebhookService] Loaded ${queue.length} pending webhooks from disk.`,
      );
    }
  } catch (e) {
    console.error("[WebhookService] Failed to load queue:", e);
    queue = [];
  }
};

const saveQueue = () => {
  try {
    fs.writeFileSync(QUEUE_FILE, JSON.stringify(queue, null, 2));
  } catch (e) {
    console.error("[WebhookService] Failed to save queue:", e);
  }
};

// Load initially
loadQueue();

// --- Main Service ---

export const WebhookService = {
  /**
   * Enqueues a webhook to be sent.
   * Returns immediately (fire-and-forget from caller's perspective).
   */
  send: (url: string, payload: any, headers: any = {}) => {
    const job: WebhookJob = {
      id: Date.now().toString() + Math.random().toString().slice(2, 6),
      url,
      payload,
      headers,
      attempts: 0,
      timestamp: new Date().toISOString(),
    };

    queue.push(job);
    saveQueue();

    // Trigger processing (don't await)
    processQueue();
  },

  /**
   * middleware to validate incoming API Key
   */
  validateApiKey: (req: any, res: any, next: any) => {
    const apiKey = req.headers["x-api-key"] || req.headers["authorization"];
    // TODO: Move key to env var
    const validKey =
      process.env.AIOPSYS_API_KEY || "konektizen-aiopsys-secret-key";

    // Check if key matches (handle 'Bearer ' prefix if present)
    const provided = apiKey?.replace("Bearer ", "");

    if (provided === validKey) {
      next();
    } else {
      res.status(403).json({ error: "Invalid API Key" });
    }
  },
};

// --- Queue Processor ---

let isProcessing = false;

const processQueue = async () => {
  if (isProcessing) return;
  if (queue.length === 0) return;

  isProcessing = true;

  // Create a copy to iterate safely
  const job = queue[0]; // Process FIFO

  try {
    console.log(
      `[WebhookService] Processing job ${job.id} (Attempt ${job.attempts + 1}/${MAX_RETRIES})...`,
    );

    await axios.post(job.url, job.payload, {
      headers: { ...job.headers, "Content-Type": "application/json" },
      timeout: 10000,
    });

    console.log(`[WebhookService] Job ${job.id} SUCCESS.`);
    // Remove from queue
    queue.shift();
    saveQueue();
  } catch (e: any) {
    console.error(`[WebhookService] Job ${job.id} FAILED: ${e.message}`);

    job.attempts++;
    if (job.attempts >= MAX_RETRIES) {
      console.error(
        `[WebhookService] Job ${job.id} MAX RETRIES REACHED. Dropping.`,
      );
      queue.shift(); // Drop it
      saveQueue();
    } else {
      // Move to back of queue or just leave at front?
      // For strict ordering, leave at front and retry after delay.
      // But to avoid blocking others, we traditionally move to back or use a separate retry queue.
      // For simplicity here: We'll just wait a bit before trying *anything* again to avoid hammering.
      await new Promise((r) => setTimeout(r, RETRY_DELAY_MS));
    }
  }

  isProcessing = false;

  // Recursively process next if any
  if (queue.length > 0) {
    processQueue();
  }
};

// Restart queue processing on startup (if any pending)
if (queue.length > 0) {
  processQueue();
}
