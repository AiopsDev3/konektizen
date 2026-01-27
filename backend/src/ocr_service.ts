import { createWorker } from 'tesseract.js';
// @ts-ignore
import stringSimilarity from 'string-similarity';

export interface VerificationResult {
  isVerified: boolean;
  extractedName: string;
  confidence: number;
  reasoning: string;
}

export async function verifyIdentityDocumentLocal(
  imagePath: string, 
  expectedName: string,
  expectedCity: string,
  expectedBarangay: string
): Promise<VerificationResult> {
  console.log(`🔍 Starting Strict Verification for: ${expectedName}, Address: ${expectedBarangay}, ${expectedCity}`);
  
  let worker;
  try {
    worker = await createWorker('eng');
    
    // 1. Recognize text
    const ret = await worker.recognize(imagePath);
    const extractedText = ret.data.text;
    console.log('📝 Extracted Text (First 100 chars):', extractedText.substring(0, 100).replace(/\n/g, ' '));
    
    await worker.terminate();

    // 2. Pre-process text
    const cleanText = extractedText
      .toUpperCase()
      .replace(/[^A-Z0-9\s]/g, ' ') 
      .replace(/\s+/g, ' ');

    const cleanName = expectedName.toUpperCase();
    const cleanCity = expectedCity.toUpperCase();
    const cleanBarangay = expectedBarangay.toUpperCase();

    // 3. Name Verification (Fuzzy Match)
    const nameParts = cleanName.split(' ').filter(p => p.length > 2);
    let matchedNameParts = 0;
    
    for (const part of nameParts) {
      const wordsInId = cleanText.split(' ');
      const bestMatch = stringSimilarity.findBestMatch(part, wordsInId);
      if (bestMatch.bestMatch.rating > 0.75) matchedNameParts++;
    }

    const nameMatchRatio = nameParts.length > 0 ? matchedNameParts / nameParts.length : 0;
    let isNameVerified = nameMatchRatio >= 0.5;

    // --- TEST MODE BYPASS ---
    // If name is "ADMIN", force name check to pass.
    // Address check (below) MUST still pass.
    if (expectedName.toUpperCase().includes('ADMIN')) {
      console.log('⚡ TEST MODE: Bypassing Name Verification for ADMIN user.');
      isNameVerified = true;
    }

    // 4. Address Verification (Strict City, Fuzzy Barangay)
    // Check City (Exact match logic within text)
    const isCityVerified = cleanText.includes(cleanCity);
    
    // Check Barangay (Fuzzy logic)
    // We try to find the barangay name in the text
    const matches = stringSimilarity.findBestMatch(cleanBarangay, cleanText.split(' '));
    // If exact substring exists OR fuzzy match of words is high
    const isBarangayVerified = cleanText.includes(cleanBarangay) || matches.bestMatch.rating > 0.8;

    console.log(`Address Check: City=${isCityVerified} (${cleanCity}), Barangay=${isBarangayVerified} (${cleanBarangay})`);

    // 5. Final Decision
    // MUST match Name AND (City OR Barangay - giving benefit of doubt if one is obscure, but ideally both)
    // User requested "Only mark as Verified when: declared city matches OCR city AND barangay reasonably matches"
    
    const isAddressVerified = isCityVerified && isBarangayVerified;
    const isVerified = isNameVerified && isAddressVerified;

    let reasoning = "";
    if (isVerified) {
      reasoning = "Identity and Address Verified.";
    } else if (!isNameVerified) {
      reasoning = `Name mismatch. Found ${matchedNameParts}/${nameParts.length} parts.`;
    } else if (!isCityVerified) {
      reasoning = `City mismatch. Expected "${expectedCity}" in ID.`;
    } else if (!isBarangayVerified) {
      reasoning = `Barangay mismatch. Expected "${expectedBarangay}" in ID.`;
    }

    return {
      isVerified,
      extractedName: cleanText.substring(0, 50) + "...", 
      confidence: (nameMatchRatio + (isAddressVerified ? 1 : 0)) / 2,
      reasoning: reasoning
    };

  } catch (error: any) {
    console.error('OCR Error:', error);
    if (worker) await worker.terminate();
    throw new Error('Local OCR Failed: ' + error.message);
  }
}
