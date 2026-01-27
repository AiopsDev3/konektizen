# KONEKTIZEN LLM Integration - Configuration Guide

## Overview

KONEKTIZEN now uses a Large Language Model (LLM) to analyze incident reports in Philippine local languages (Filipino, Tagalog, Taglish, and regional dialects). This guide explains how to configure and deploy the system.

## Backend Configuration

### 1. Install Dependencies

Navigate to the backend directory and install npm packages:

```bash
cd backend
npm install
```

This will install:

- `@google/generative-ai` - Google Gemini SDK
- `node-cache` - Response caching
- Other existing dependencies

### 2. Configure Environment Variables

Create or update the `.env` file in the `backend` directory:

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/konektizen"

# JWT Secret
JWT_SECRET="konektizen_super_secret_key"

# LLM Configuration
LLM_PROVIDER=gemini
GEMINI_API_KEY=your_actual_gemini_api_key_here
LLM_MODEL=gemini-1.5-flash
LLM_CACHE_TTL=3600
LLM_MAX_RETRIES=3
```

### 3. Get a Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Get API Key" or "Create API Key"
4. Copy the API key
5. Replace `your_actual_gemini_api_key_here` in `.env` with your key

**Note**: Gemini API offers a generous free tier. Check current pricing at [ai.google.dev/pricing](https://ai.google.dev/pricing)

### 4. Start the Backend Server

```bash
npm run dev
```

The server will start on `http://localhost:3000`

### 5. Test the LLM Endpoint

Test the health check:

```bash
curl http://localhost:3000/api/llm/health
```

Expected response:

```json
{
  "status": "configured",
  "provider": "gemini",
  "model": "gemini-1.5-flash"
}
```

Test analysis (Filipino example):

```bash
curl -X POST http://localhost:3000/api/llm/analyze \
  -H "Content-Type: application/json" \
  -d '{"description": "May malaking butas sa kalsada sa Rizal Street, Naga City"}'
```

## Flutter Frontend Configuration

### 1. Update Backend URL

Edit `lib/core/ai/llm_service.dart` and update the `baseUrl`:

```dart
// For Android Emulator
static const String baseUrl = 'http://10.0.2.2:3000';

// For iOS Simulator
static const String baseUrl = 'http://localhost:3000';

// For Physical Device (replace with your computer's IP)
static const String baseUrl = 'http://192.168.1.XXX:3000';
```

To find your computer's IP:

- **Windows**: Run `ipconfig` and look for IPv4 Address
- **Mac/Linux**: Run `ifconfig` and look for inet address

### 2. Run the Flutter App

```bash
flutter pub get
flutter run
```

## Testing the Integration

### Test Scenarios

#### 1. Filipino Language Input

```
Input: "May malaking butas sa kalsada sa Rizal Street, Naga City. Delikado para sa mga motorsiklo."
Expected: Roads & Infra, Medium-High severity, Naga City detected
```

#### 2. Taglish Input

```
Input: "Grabe yung traffic sa EDSA dahil sa aksidente. May nahulog na poste."
Expected: Traffic or Safety & Emergency, detects mixed language
```

#### 3. Emergency (High Urgency)

```
Input: "Sunog! May nasusunog na bahay sa Taft Avenue. Tulong!"
Expected: Safety & Emergency, High severity, Critical urgency
```

#### 4. English Fallback

```
Input: "There is a fire near SM Mall. Please send help immediately."
Expected: System understands and categorizes correctly
```

## Fallback Behavior

If the LLM API is unavailable or not configured:

- The system automatically falls back to keyword-based analysis
- Users can still submit reports
- Analysis quality will be reduced but functional

## Cost Optimization

The system includes several cost-saving features:

1. **Response Caching**: Identical descriptions are cached for 1 hour (configurable via `LLM_CACHE_TTL`)
2. **Retry Logic**: Failed requests retry with exponential backoff
3. **Fallback**: If API fails, uses free keyword-based analysis

### Estimated Costs (Gemini API)

- **Free Tier**: 60 requests per minute, 1,500 requests per day
- **Paid Tier**: ~$0.001-0.01 per analysis (varies by model and input length)

For most civic applications, the free tier should be sufficient.

## Troubleshooting

### "Cannot connect to LLM service"

**Solution**: Check that:

1. Backend server is running (`npm run dev`)
2. `baseUrl` in `llm_service.dart` is correct
3. Firewall allows connections to port 3000

### "Health check shows fallback_mode"

**Solution**:

1. Verify `GEMINI_API_KEY` is set in `.env`
2. Ensure API key is valid (test at Google AI Studio)
3. Restart the backend server after updating `.env`

### Analysis takes too long

**Solution**:

1. Check internet connection
2. Consider using `gemini-1.5-flash` instead of `gemini-pro` (faster, cheaper)
3. Reduce `LLM_MAX_RETRIES` if needed

### "Invalid API key" error

**Solution**:

1. Regenerate API key at Google AI Studio
2. Ensure no extra spaces in `.env` file
3. Restart backend after updating key

## Production Deployment

### Security Checklist

- [ ] Use environment variables for all secrets
- [ ] Never commit `.env` file to git
- [ ] Use HTTPS in production
- [ ] Implement rate limiting on LLM endpoints
- [ ] Monitor API usage and costs
- [ ] Set up error alerting

### Recommended Setup

1. **Backend**: Deploy to cloud service (Heroku, Railway, Google Cloud Run)
2. **Environment**: Use platform's environment variable management
3. **Monitoring**: Set up logging for LLM requests and errors
4. **Scaling**: Enable caching and consider CDN for static assets

## Alternative LLM Providers

If you prefer a different LLM provider:

### OpenAI GPT-4o

```env
LLM_PROVIDER=openai
OPENAI_API_KEY=your_openai_key
LLM_MODEL=gpt-4o-mini
```

Update `llm_service.ts` to use OpenAI SDK instead of Gemini.

### Cohere

```env
LLM_PROVIDER=cohere
COHERE_API_KEY=your_cohere_key
LLM_MODEL=command
```

Update `llm_service.ts` to use Cohere SDK.

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review backend logs: `npm run dev` output
3. Test API endpoints directly with curl
4. Verify environment variables are loaded correctly

---

**Last Updated**: January 2026
**LLM Provider**: Google Gemini (recommended for Filipino language support)
