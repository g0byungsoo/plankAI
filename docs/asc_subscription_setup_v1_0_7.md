# App Store Connect — v1.0.7 Subscription Setup Checklist

**Status:** The Python script (`Scripts/asc_create_subscriptions.py --create-only`) already created all 6 new subscriptions in ASC with English (U.S.) localization. **What's left is 3 things per product**: upload screenshot, set US price, set intro offer (only for yearly + quarterly).

**Time budget:** ~30 min total.

---

## What the script already did ✅

For each of the 6 new products:
- Created the subscription within the JeniFit Pro group (ID 22062149)
- Set Reference Name + Product ID + Duration + Group Level
- Added English (U.S.) Subscription Display Name + Description

You should see these in ASC with status **"Missing Metadata"** — they're waiting on screenshot + price + intro offer to flip to **"Ready to Submit"**.

| Product ID | Reference Name | Duration | Level | Display Name | Description |
|---|---|---|---|---|---|
| `jenifit_yearly_v2` | JeniFit Yearly v2 | 1 year | 1 | JeniFit Annual | Full JeniFit access. Cancel anytime. |
| `jenifit_quarterly` | JeniFit Quarterly | 3 months | 2 | JeniFit Quarterly | 3 months of JeniFit. The 12-week becoming arc. |
| `jenifit_weekly_v2` | JeniFit Weekly v2 | 1 week | 3 | JeniFit Weekly | Try JeniFit one week at a time. No commitment. |
| `jenifit_yearly_discount_v2` | JeniFit Yearly Discount v2 | 1 year | 4 | JeniFit Annual (special offer) | First-year discount. Renews at standard rate. |
| `jenifit_quarterly_discount` | JeniFit Quarterly Discount | 3 months | 5 | JeniFit Quarterly (special offer) | First-quarter discount. Renews at standard rate. |
| `jenifit_weekly_discount` | JeniFit Weekly Discount | 1 week | 6 | JeniFit Weekly (special offer) | First-week discount. Renews at standard rate. |

---

## What you need to do manually (3 things × 6 products)

For each of the 6 products in `App Store Connect → JeniFit → Monetization → Subscriptions → JeniFit Pro`:

1. **Upload screenshot** (same image for all 6)
2. **Set US price** (per the table below)
3. **Set 3-day free trial** — **ONLY for `jenifit_yearly_v2`**. The other 5 products skip this entirely.

> **Why annual-only trial** (research-decided 2026-05-30):
> Apple's "one intro offer per group per user, lifetime" rule means that if a user takes the quarterly trial, they can never claim the annual trial later. Symmetric trials cannibalize annual: in 3-tier paywalls with trial-badged mid-tier, 55-65% of trial-starters pick the cheaper tier (Adapty 2026 H&F). Annual-only trial modeled +2.1× blended revenue. Cal AI direct analog runs annual-only. The quarterly tier still wins users on goal-horizon match (12-week brand frame); it doesn't need a trial to compete.

> **Downsell strategy locked 2026-05-30** (tier-matched, weekly excluded):
> All 6 SKUs ship to ASC. The transaction-abandon downsell fires tier-matched: annual abandon → `jenifit_yearly_discount_v2` ($35.99), quarterly abandon → `jenifit_quarterly_discount` ($18.74), weekly abandon → **NO downsell fires** (price-insensitive cohort, training risk). `jenifit_weekly_discount` still ships to ASC for future iOS 18 winback flows. Tier-matched recovers 15-25% of abandons vs 3-8% for tier-switching (RevenueCat 2026 exit-offer data).

---

## Step 0: Prepare the universal screenshot (do this ONCE)

Apple requires one App Store Review screenshot per subscription. You'll upload the **same image** 6 times.

1. Open the JeniFit simulator or device, navigate to the paywall screen
2. Take a screenshot (Cmd+S on simulator, or any iOS screenshot)
3. Save somewhere accessible

Requirements: 640×920 minimum. Any iPhone screenshot exceeds this easily. The image is NOT shown to users — only Apple's reviewer.

---

## Step 1: Per-product checklist

For each product, click into it from the JeniFit Pro group page, then do the 3 things below. Order doesn't matter; do whichever section first.

### Section A: Upload screenshot (all 6 products)
- Scroll to **App Store Review Information** section
- Click "Choose File" under **Review Screenshot**
- Upload your universal screenshot
- Leave Review Notes blank
- Save

### Section B: Set US price (all 6 products)
- Scroll to **Subscription Prices** section
- Click "Edit Pricing" (or "Set Starting Price")
- Choose **United States** as starting country
- Pick price from the per-product table below
- Apple will auto-fill all other territories using their exchange-rate matrix. Click "Next" → "Confirm"

### Section C: Set 3-day free trial (ONLY for `jenifit_yearly_v2`)
**The other 5 products skip this section entirely.** Annual-only trial is the research-decided pattern — see the "Why annual-only trial" note above.

- Scroll to **Introductory Offers** section
- Click **"+"** (Create Introductory Offer)
- Offer Type: **Pay As You Go** → then pick **Free**
- Duration: **3 days**
- Number of Periods: **1**
- Eligible Customers: **New Subscribers**
- Country/Region: **All Countries or Regions**
- Start Date: **Immediately** (or leave default)
- End Date: **No End Date**
- Save

---

## Per-product reference table

| Product | US Price | Intro Offer |
|---|---|---|
| `jenifit_yearly_v2` | **$47.99** | **3-day free trial** ✓ |
| `jenifit_quarterly` | **$24.99** | ✗ skip (annual-only trial strategy) |
| `jenifit_weekly_v2` | **$5.99** | ✗ skip |
| `jenifit_yearly_discount_v2` | **$35.99** (25% off $47.99) | ✗ skip |
| `jenifit_quarterly_discount` | **$18.74** (25% off $24.99) | ✗ skip |
| `jenifit_weekly_discount` | **$4.49** (25% off $5.99) | ✗ skip |

---

## Step 2: Verify

After completing all 3 things on all 6 products, refresh the JeniFit Pro group page. All 6 new products should now show **"Ready to Submit"** status.

```
Level 1: JeniFit Yearly v2          jenifit_yearly_v2          1 year     Ready to Submit
Level 2: JeniFit Quarterly          jenifit_quarterly          3 months   Ready to Submit
Level 3: JeniFit Weekly v2          jenifit_weekly_v2          1 week     Ready to Submit
Level 4: JeniFit Yearly Discount v2 jenifit_yearly_discount_v2 1 year     Ready to Submit
Level 5: JeniFit Quarterly Discount jenifit_quarterly_discount 3 months   Ready to Submit
Level 6: JeniFit Weekly Discount    jenifit_weekly_discount    1 week     Ready to Submit
─── (legacy, untouched) ───
Level 7: JeniFit weekly              absmaxxing_weekly          1 week    Approved
Level 8: JeniFit yearly              absmaxxing_yearly          1 year    Approved
Level 9: JeniFit yearly discount     jenifit_yearly_discount    1 year    Approved
```

The exact level ordering of legacy products may shift — Apple auto-assigns based on creation order. What matters is that all 9 exist.

---

## Step 3 (optional, recommended): Rename the group display name

While you're in ASC, fix the "absmaxxing pro" name that users see in iOS Settings → Subscriptions.

1. Click **Edit Subscription Group** (in JeniFit Pro page header)
2. Find English (U.S.) localization
3. Subscription Group Display Name: **JeniFit Pro**
4. App Name: leave as-is or change to **JeniFit**
5. Save

This is user-visible — existing subscribers will see "JeniFit Pro" instead of "absmaxxing pro" in their iOS subscription management screen after the next app version is approved.

---

## Step 4 (optional): PPP territory overrides — 15 emerging markets

Skippable for v1 — Apple's auto-conversion handles all territories. Only do this round if you want PPP-aware pricing in PH/IN/BR/etc. now rather than later.

To override a territory:
- Subscription → Subscription Prices → Edit Pricing → Select country → Pick custom price tier

| Territory | Annual | Quarterly | Weekly | Annual Discount | Qtr Discount | Weekly Discount |
|---|---|---|---|---|---|---|
| 🇵🇭 PHL | ₱1,490 | ₱790 | ₱179 | ₱1,090 | ₱590 | ₱134 |
| 🇲🇽 MEX | $499 | $269 | $59 | $379 | $199 | $44 |
| 🇧🇷 BRA | R$129 | R$69 | R$15.90 | R$99 | R$49 | R$11.90 |
| 🇨🇱 CHL | $26,990 | $13,990 | $3,290 | $20,990 | $10,490 | $2,490 |
| 🇨🇴 COL | $99,000 | $49,000 | $11,900 | $74,000 | $37,000 | $8,900 |
| 🇵🇪 PER | S/ 89 | S/ 45 | S/ 9.90 | S/ 65 | S/ 33 | S/ 7.50 |
| 🇮🇳 IND | ₹1,499 | ₹799 | ₹179 | ₹1,099 | ₹599 | ₹134 |
| 🇮🇩 IDN | Rp 249,000 | Rp 129,000 | Rp 29,000 | Rp 189,000 | Rp 95,000 | Rp 22,000 |
| 🇻🇳 VNM | ₫349,000 | ₫179,000 | ₫39,000 | ₫269,000 | ₫135,000 | ₫29,000 |
| 🇹🇭 THA | ฿549 | ฿279 | ฿65 | ฿419 | ฿209 | ฿49 |
| 🇲🇾 MYS | RM 89 | RM 45 | RM 9.90 | RM 69 | RM 35 | RM 7.50 |
| 🇪🇬 EGY | E£499 | E£259 | E£59 | E£379 | E£189 | E£44 |
| 🇿🇦 ZAF | R 369 | R 189 | R 44 | R 279 | R 139 | R 33 |
| 🇦🇷 ARG | $29.99 USD | $15.99 USD | $3.99 USD | $22.99 USD | $11.99 USD | $2.99 USD |
| 🇹🇷 TUR | $24.99 USD | $12.99 USD | $2.99 USD | $18.99 USD | $9.99 USD | $2.49 USD |

**Note on ARG + TUR:** Currency inflation. Apple supports USD-pegged pricing in both — pick the closest USD tier rather than local currency to avoid monthly re-pricing churn.

---

## Step 5: Submit with next app version

You don't submit subscriptions individually for review. They go through App Review **bundled with your next app version submission**. So when you submit JeniFit v1.0.7 to the App Store, all 6 new subscriptions ride along automatically.

Apple typically approves IAP-only changes within 24h once submitted with a binary.

---

## Step 6 (after Apple approves): RevenueCat dashboard

Once Apple flips the 6 subs from "Ready to Submit" → "Waiting for Review" → "Approved", do this in RevenueCat:

### 6A. Products page (sync + entitlement)
- Click "Sync products" button (or wait ~5 min for auto-sync)
- For each of the 6 new products that appear, click → Attach Entitlement → select **pro** → Save

End state: the `pro` entitlement is attached to **9 products** (3 legacy + 6 new).

### 6B. Offerings page → `default`
- Click `default` offering → Edit Packages
- Remove the existing 2 packages
- Add 3 new packages:
  - Package: **$rc_annual** → Product: `jenifit_yearly_v2`
  - Package: **$rc_three_month** → Product: `jenifit_quarterly`
  - Package: **$rc_weekly** → Product: `jenifit_weekly_v2`
- Save

### 6C. Offerings page → `discount`
- Click `discount` offering → Edit Packages
- Remove the existing 1 package
- Add 3 new packages:
  - Package: **$rc_annual** → Product: `jenifit_yearly_discount_v2`
  - Package: **$rc_three_month** → Product: `jenifit_quarterly_discount`
  - Package: **$rc_weekly** → Product: `jenifit_weekly_discount`
- Save

---

## Step 7: Ping Claude

Send a message saying **"RC offerings live"** and I'll do the final code work:
1. Flip the 3 active constants in `RevenueCatConfig.swift` from legacy `absmaxxing_*` IDs to `V2.*` (single edit; already pre-staged)
2. Verify the quarterly card now renders end-to-end in the paywall (it's already coded; just needs the RC offering update to surface)
3. Update `DownsellPaywallView.swift` to look up the tier-specific discount product based on which tier the user just abandoned (currently uses the legacy 50% discount as fallback)
4. Build + verify clean

---

## Existing customer protection — confirmed throughout

Throughout this whole flow, the 3 legacy products (`absmaxxing_weekly`, `absmaxxing_yearly`, `jenifit_yearly_discount`) are NEVER edited. Existing v1.0-v1.0.6 subscribers continue renewing at their current prices ($4.99/wk, $69.99/yr, $34.99/yr) indefinitely. The `pro` entitlement stays attached to all 9 products (3 legacy + 6 new), so subscriber access continues regardless of which product they're on.

---

## Why we ended up doing screenshot+price+intro-offer manually

The script DID work for:
- Creating all 6 subscriptions
- Setting English localization
- Idempotent re-runs

The script COULDN'T work for:
- **Screenshot upload** — Apple's media upload endpoint requires multipart asset upload (200+ lines of fiddly code for a 6-click manual task)
- **Initial pricing** — Apple's API returns `ENTITY_ERROR.RELATIONSHIP.INVALID` for any subscription in `MISSING_METADATA` state (which is the initial state of every new subscription). The screenshot + price are both required to leave `MISSING_METADATA`. Apple's web UI handles the bootstrap differently than the public API exposes.

For one-time setup, manual UI is the right call. Future per-product price tweaks CAN use the API once the products are in `Approved` state — the script will work for those.

---

## Quick reference: total manual work

| Action | Count | Time per | Total |
|---|---|---|---|
| Take universal screenshot | 1 | 2 min | 2 min |
| Upload screenshot | 6 | 1 min | 6 min |
| Set US price | 6 | 2 min | 12 min |
| Set 3-day intro offer | **1 (annual only)** | 2 min | 2 min |
| Verify "Ready to Submit" status | 1 | 2 min | 2 min |
| Rename group display name (optional) | 1 | 3 min | 3 min |
| **Active time** | | | **~27 min** |
| Apple review wait (after binary submit) | | | ~24h |
| RevenueCat reconfig (after Apple approves) | | | 10 min |
