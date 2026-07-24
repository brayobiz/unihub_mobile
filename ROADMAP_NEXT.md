# Ulify Mobile - Next Version Strategy (The "Trust & Partner" Phase)

This roadmap outlines the transition from a pure community tool to a moderated, monetized campus ecosystem without relying on external Ad SDKs.

## 1. Native Monetization (Kenyan Brand Partnerships)
**Goal**: Generate revenue by integrating local brands directly into the UI.
- **Partner Badges**: Add an `isPartner` boolean to the `User` model. Partnered accounts get a "Verified Brand" badge (e.g., gold checkmark).
- **Sponsored Gigs**: Allow brands to post "Brand Ambassador" or "Student Task" roles in the Gigs section, pinned to the top.
- **Marketplace Spotlights**: Injected "Native" cards for brands (e.g., "Student Laptop Deals by [Brand]") that look like marketplace items but lead to partner links.
- **Management**: Initial billing via M-Pesa (offline) with manual Firestore status updates (`partnerExpiry`).

## 2. "Trust Economy" Enhancements & Micro-Revenue
**Goal**: Solidify the platform as the "Scam-Free" alternative to WhatsApp groups while generating survival revenue.
- **Blue-Tick Student Verification**: 
    - Implement a "Request Verification" flow where students upload ID/Enrollment proof.
    - **Monetization**: Charge a one-time "Trust Fee" (e.g., 150 KES) for the Verified Badge.
    - Manual review by admins to ensure "Comrade-to-Comrade" safety.
- **Escrow-Lite**: Add a "Mark as Safe Transaction" button that logs successful on-campus trades to boost both users' Trust Scores.
- **Partner Trust Override**: Manually set Trust Scores to 100% for verified Kenyan brands.
- **Featured Listings**: Allow sellers to "Boost" their items to the top of the Marketplace/Housing feed for a small fee (e.g., 50 KES for 24 hours).

## 3. Automated Moderation & "Proactive Matchmaking" (Gemini AI Layer)
**Goal**: Use existing Gemini integration to lower the burden on human moderators and proactively connect users.
- **Content Pre-Screening**: Use `AIAssistantService` to scan new Marketplace/Gig posts for:
    - Off-platform payment requests (scam detection).
    - Toxic language or hate speech.
    - Duplicate/Spam patterns.
- **AI Matchmaker (Proactive Notifications)**:
    - **Request Detection**: AI monitors the "Community Feed" for requests (e.g., "I need a roommate in KM" or "Looking for a 6kg Gas cylinder").
    - **Smart Alerts**: If a new listing matches a recent user request, the AI triggers a push notification: *"Hey, I found a match for the roommate request you posted yesterday! Check it out here."*
- **Auto-Flagging**: If Gemini detects a 70%+ probability of a scam, the post is hidden and moved to a `moderation_queue` for manual review.

## 4. Performance & Distribution
**Goal**: Keep the app light and accessible.
- **Optimized APKs**: Shift to targeted ARM64 builds (~28MB) for APKPure to ensure high conversion rates on Kenyan campus networks.
- **Offline Reliability**: Maintain "Offline-First" capability using Firestore persistence for core feeds (Home, Market).

## 5. Community "Wanted" & Request System
**Goal**: Disrupt the "Agent" model by allowing students to bypass middlemen for specific needs.
- **"I'm Looking For..." Mode**: A dedicated toggle in the Marketplace/Housing tabs for "Buyer Requests."
- **Direct Matching**: Allow "Plugs" like *Tajiri* to see a live feed of what students currently need, turning the app into a lead-generation tool for them.
- **Anti-Broker Transparency**: Display "No Viewing Fee" badges for listings that allow students to visit without upfront charges.

## 6. Future Preview (The 2-Year Vision)
- **Student Employment**: Hiring "Campus Leads" as paid moderators using brand revenue.
- **Integrated Payments**: M-Pesa STK Push for in-app escrow and service fees.
- **Campus OS**: Expanding from a tool to a nationwide Student Identity and Credit platform.

---
*Generated for Version: 1.0.1+4 (Targeting APKPure Release)*
