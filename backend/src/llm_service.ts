import { GoogleGenerativeAI } from '@google/generative-ai';
import NodeCache from 'node-cache';
import * as dotenv from 'dotenv';

dotenv.config();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');
const model = genAI.getGenerativeModel({ model: process.env.LLM_MODEL || 'gemini-1.5-flash' });

// Cache for LLM responses (TTL from env or default 1 hour)
const cache = new NodeCache({ stdTTL: parseInt(process.env.LLM_CACHE_TTL || '3600') });

export interface LLMAnalysisResult {
  category: string;
  severity: 'low' | 'medium' | 'high';
  urgency: string;
  detectedCity?: string;
  confidence: number;
  language: string;
  reasoning?: string;
}

// Filipino-optimized system prompt
const SYSTEM_PROMPT = `Ikaw ay isang AI assistant para sa KONEKTIZEN, isang civic engagement platform sa Pilipinas. 
Ang iyong trabaho ay suriin ang mga ulat ng mga mamamayan tungkol sa mga problema sa kanilang komunidad.

IMPORTANTE: Dapat mong maintindihan at masagot sa Filipino, Tagalog, Taglish (code-switched Filipino-English), 
at iba pang regional dialects ng Pilipinas. Ang English ay pangalawang wika lamang.

Para sa bawat ulat, tukuyin ang:
1. CATEGORY - Pumili mula sa: "Roads & Infra", "Safety & Emergency", "Sanitation", "Traffic", "Utilities", "Public Concern"
2. SEVERITY - low, medium, o high
3. URGENCY - Gaano kabilis kailangan aksyunan (Low, Medium, High, Critical)
4. DETECTED_CITY - Kung nabanggit ang lungsod (Manila, Cebu, Davao, Quezon City, Naga, etc.)
5. LANGUAGE - Anong wika ginamit (Filipino, Taglish, English, Cebuano, etc.)
6. CONFIDENCE - 0.0 to 1.0, gaano ka sigurado sa analysis

MGA HALIMBAWA:
- "May malaking butas sa kalsada" → Roads & Infra, medium severity
- "Sunog! Tulong!" → Safety & Emergency, high severity, Critical urgency
- "Grabe ang traffic sa EDSA" → Traffic, medium severity
- "Basura everywhere sa Colon Street" → Sanitation, low-medium severity
- "Walang kuryente since kahapon" → Utilities, high severity

Magbigay ng JSON response LAMANG, walang ibang text:
{
  "category": "category name",
  "severity": "low|medium|high",
  "urgency": "Low|Medium|High|Critical",
  "detectedCity": "city name or null",
  "language": "detected language",
  "confidence": 0.0-1.0,
  "reasoning": "short explanation in Filipino"
}`;

// Fallback keyword-based analysis (when LLM fails)
function fallbackAnalysis(text: string): LLMAnalysisResult {
  const lower = text.toLowerCase();
  
  // City Detection
  let city: string | undefined;
  if (lower.includes('manila')) city = 'Manila City';
  else if (lower.includes('cebu')) city = 'Cebu City';
  else if (lower.includes('davao')) city = 'Davao City';
  else if (lower.includes('quezon')) city = 'Quezon City';
  else if (lower.includes('naga')) city = 'Naga City';

  // Language detection (simple)
  let language = 'Filipino';
  if (/^[a-zA-Z\s.,!?]+$/.test(text)) language = 'English';
  else if (/[a-zA-Z]/.test(text) && /[ñáéíóú]|ng|mga|sa|ang/.test(lower)) language = 'Taglish';

  // Category & Severity
  if (lower.includes('road') || lower.includes('kalsada') || lower.includes('pothole') || lower.includes('butas')) {
    return {
      category: 'Roads & Infra',
      severity: 'medium',
      urgency: 'Medium',
      detectedCity: city,
      confidence: 0.6,
      language,
      reasoning: 'Keyword-based fallback analysis'
    };
  } else if (lower.includes('flood') || lower.includes('baha') || lower.includes('fire') || lower.includes('sunog') || 
             lower.includes('danger') || lower.includes('delikado') || lower.includes('emergency')) {
    return {
      category: 'Safety & Emergency',
      severity: 'high',
      urgency: 'High',
      detectedCity: city,
      confidence: 0.7,
      language,
      reasoning: 'Keyword-based fallback analysis'
    };
  } else if (lower.includes('garbage') || lower.includes('basura') || lower.includes('trash') || lower.includes('waste')) {
    return {
      category: 'Sanitation',
      severity: 'low',
      urgency: 'Low',
      detectedCity: city,
      confidence: 0.6,
      language,
      reasoning: 'Keyword-based fallback analysis'
    };
  } else if (lower.includes('traffic') || lower.includes('trapiko')) {
    return {
      category: 'Traffic',
      severity: 'medium',
      urgency: 'Medium',
      detectedCity: city,
      confidence: 0.6,
      language,
      reasoning: 'Keyword-based fallback analysis'
    };
  } else if (lower.includes('kuryente') || lower.includes('electricity') || lower.includes('power') || 
             lower.includes('tubig') || lower.includes('water')) {
    return {
      category: 'Utilities',
      severity: 'medium',
      urgency: 'Medium',
      detectedCity: city,
      confidence: 0.6,
      language,
      reasoning: 'Keyword-based fallback analysis'
    };
  }

  return {
    category: 'Public Concern',
    severity: 'medium',
    urgency: 'Medium',
    detectedCity: city,
    confidence: 0.5,
    language,
    reasoning: 'Keyword-based fallback analysis'
  };
}

// Main LLM analysis function
export async function analyzeIncidentReport(description: string): Promise<LLMAnalysisResult> {
  if (!description || description.trim().length === 0) {
    throw new Error('Description cannot be empty');
  }

  // Check cache first
  const cacheKey = `llm_analysis_${description.toLowerCase().trim()}`;
  const cached = cache.get<LLMAnalysisResult>(cacheKey);
  if (cached) {
    console.log('✓ Returning cached LLM analysis');
    return cached;
  }

  // Check if API key is configured
  if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY === 'your_gemini_api_key_here') {
    console.warn('⚠ Gemini API key not configured, using fallback analysis');
    return fallbackAnalysis(description);
  }

  const maxRetries = parseInt(process.env.LLM_MAX_RETRIES || '3');
  let lastError: Error | null = null;

  // Retry logic with exponential backoff
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`🤖 Calling Gemini API (attempt ${attempt}/${maxRetries})...`);
      
      const prompt = `${SYSTEM_PROMPT}\n\nULAT NG MAMAMAYAN:\n"${description}"\n\nANALYSIS (JSON only):`;
      
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      // Parse JSON response
      let jsonText = text.trim();
      
      // Remove markdown code blocks if present
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.replace(/```json\n?/g, '').replace(/```\n?/g, '');
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.replace(/```\n?/g, '');
      }

      const analysis: LLMAnalysisResult = JSON.parse(jsonText);

      // Validate response
      if (!analysis.category || !analysis.severity || !analysis.urgency) {
        throw new Error('Invalid LLM response: missing required fields');
      }

      // Ensure confidence is set
      if (!analysis.confidence) {
        analysis.confidence = 0.8;
      }

      // Cache the result
      cache.set(cacheKey, analysis);
      
      console.log('✓ LLM analysis successful:', analysis);
      return analysis;

    } catch (error: any) {
      lastError = error;
      console.error(`✗ LLM API error (attempt ${attempt}/${maxRetries}):`, error.message);

      // Wait before retry (exponential backoff)
      if (attempt < maxRetries) {
        const waitTime = Math.pow(2, attempt) * 1000; // 2s, 4s, 8s
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }

  // All retries failed, use fallback
  console.warn('⚠ All LLM retries failed, using fallback analysis');
  console.error('Last error:', lastError?.message);
  
  return fallbackAnalysis(description);
}

// Health check function
export async function checkLLMHealth(): Promise<{ status: string; provider: string; model: string }> {
  const hasApiKey = !!(process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY !== 'your_gemini_api_key_here');
  
  return {
    status: hasApiKey ? 'configured' : 'fallback_mode',
    provider: process.env.LLM_PROVIDER || 'gemini',
    model: process.env.LLM_MODEL || 'gemini-1.5-flash'
  };
}

// --- ID Verification ---
import fs from 'fs';

export interface VerificationResult {
  isVerified: boolean;
  extractedName: string;
  confidence: number;
  reasoning: string;
}

function fileToGenerativePart(path: string, mimeType: string) {
  return {
    inlineData: {
      data: Buffer.from(fs.readFileSync(path)).toString("base64"),
      mimeType
    },
  };
}

export async function verifyIdentityDocument(imagePath: string, expectedName: string): Promise<VerificationResult> {
  // Check if API key is configured
  if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY === 'your_gemini_api_key_here') {
    console.warn('⚠ Gemini API key not configured, skipping verification');
    // Fallback: Just return unverified if no AI
    return {
      isVerified: false,
      extractedName: "Unknown (No AI)",
      confidence: 0.0,
      reasoning: "AI service not configured"
    };
  }

  try {
    console.log(`🤖 Verify ID for: ${expectedName}`);
    
    // Determine mime type from extension
    const ext = imagePath.split('.').pop()?.toLowerCase() || 'jpg';
    const mimeType = ext === 'png' ? 'image/png' : 'image/jpeg';
    
    const imagePart = fileToGenerativePart(imagePath, mimeType);
    
    const prompt = `
      Analyze this ID card image.
      Goal: Verify if this ID belongs to "User Name: ${expectedName}".
      
      Instructions:
      1. Extract the full name printed on the ID.
      2. Compare the extracted name with "${expectedName}". Allow for minor spelling matches or middle name variations.
      3. Return ONLY a JSON object:
      {
        "isVerified": boolean, // true if name strongly matches
        "extractedName": "name found on ID",
        "confidence": 0.0-1.0, // confidence in the OCR and match
        "reasoning": "short explanation"
      }
    `;

    const result = await model.generateContent([prompt, imagePart]);
    const response = await result.response;
    const text = response.text();
    
    // Parse JSON response (cleanup markup)
    let jsonText = text.trim()
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '');
      
    const analysis: VerificationResult = JSON.parse(jsonText);
    console.log('✓ Verification Result:', analysis);
    return analysis;

  } catch (error: any) {
    console.error('OCR Verification Failed:', error.message);
    throw new Error('Failed to verify ID document');
  }
}
