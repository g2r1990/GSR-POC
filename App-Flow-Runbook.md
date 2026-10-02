# GSR — Application Flow Runbook
**Document Type:** Product & Business Flow (Non-Technical)  
**Last Updated:** 2026-10-04  
**Audience:** Business stakeholder, product owner  
**Purpose:** Describes how the app works for each user type — no code or infrastructure details

---

## Who Uses GSR?

GSR has three distinct user types. Each has a separate login and a separate part of the app.

| User | Who they are | How they log in |
|---|---|---|
| **Admin** | Gurpreet (you) — approves restaurants | Username + Password + Google Authenticator |
| **Restaurant Owner** | Restaurant business owner wanting to list on GSR | Mobile number + Password |
| **Customer** | Person who searches for and orders food | Pincode search (no login required to browse) |

---

## Journey 1 — Restaurant Owner Onboarding

This is how a new restaurant gets listed on GSR.

### Step 1: Owner Discovers GSR
- Owner hears about GSR through word of mouth, referral, or social media
- Downloads the GSR app from the link shared by Admin

### Step 2: Owner Self-Registers
- Opens app → taps **"Restaurant Owner"** → taps **"Register"**
- Enters:
  - **GSTIN** (15-digit business tax number) — this is the unique identifier
  - Full name
  - Mobile number
  - Email address
  - Restaurant name, full address, area, pincode
  - Food type: Pure Veg / Non-Veg / Both

> **Same GSTIN = Same Owner.**  
> If an owner has two restaurants under the same GSTIN, both restaurants are linked to one owner account. They can manage all restaurants from a single login.

### Step 3: Admin Reviews the Application
- Admin (Gurpreet) receives a notification of the new registration
- Logs into the GSR Admin panel
- Reviews the owner's details:
  - Is the GSTIN valid?
  - Does the restaurant name match the GSTIN record?
  - Is the address legitimate?
- Takes one of two actions:
  - **Approve** → owner account becomes active
  - **Reject** → rejection reason is recorded and sent to owner

### Step 4: Owner Gets Notified
After Admin approves:
- Owner receives an **SMS** to their registered mobile: "Your GSR account is approved! Login with your mobile number."
- Owner receives an **email** to their registered email: "Welcome to GSR — your restaurant is approved. [Download App Link]"

### Step 5: Owner Sets Up the App
- Owner logs in with their mobile number + password
- Sees the **Owner Dashboard**
- Taps **"Manage Menu"** → adds all menu items:
  - Category (Starters, Main Course, Rice, Indian Bread, Drinks, Desserts, etc.)
  - Item name
  - Description (optional)
  - Price (₹)
- Reviews and accepts the **GSR Terms & Conditions**

> **Terms & Conditions** (to be prepared by Gurpreet) will cover:
> - Commission structure (if any)
> - Food safety responsibility
> - Order fulfilment expectations
> - Cancellation policy

### Step 6: Restaurant Goes Live
- After T&C acceptance, the restaurant status changes to **Active**
- Restaurant now appears in customer pincode search immediately
- Customers can browse the menu and place orders

---

## Journey 2 — Customer Orders Food

This is how a regular person uses GSR to find and order food.

### Step 1: Customer Discovers GSR
- Hears about GSR through a local restaurant, friend, or social media
- Downloads the app OR opens the web version (future)

### Step 2: Search for Restaurants
- Opens app → taps **"Customer"**
- Enters their **6-digit pincode** (e.g. 431003 for Cidco area)
- Taps **"Find Restaurants"**
- Sees a list of all active restaurants in that pincode area
- Each restaurant card shows: name, area, food type (Veg / Non-Veg / Both)

> **No login required to browse.** Customer can see restaurants and menus without creating an account.

### Step 3: Browse the Menu
- Taps a restaurant card → sees the full menu
- Items are grouped by category
- Only **available items** appear (owner controls this with the availability toggle)
- Sees item name, description, and price in ₹

### Step 4: Place an Order
- Selects items → adds to cart
- Reviews cart (item names + prices)
- Enters delivery address
- Reviews order total
- Places order

> **Payment is Cash or UPI (PhonePe / Google Pay) on delivery.**  
> No in-app payment in Phase 1 — the delivery person collects payment.

### Step 5: Order Confirmation
- Customer receives an order number
- SMS confirmation sent to mobile: "Your order #GSR-001 from Noor Bhoj is placed. Estimated delivery: 30–45 mins."

### Step 6: Order Status Updates
Customer can track their order through these stages:

```
PLACED → ACCEPTED → READY → OUT FOR DELIVERY → DELIVERED
```

- **Placed:** Customer submitted the order. Owner not yet confirmed.
- **Accepted:** Owner confirmed — kitchen is preparing it.
- **Ready:** Food is packed and ready for pickup by delivery rider.
- **Out for Delivery:** Rider has picked up the order.
- **Delivered:** Order handed to customer. Payment collected.

---

## Journey 3 — Admin Manages the Platform

This is how Gurpreet (Admin) manages the GSR platform day-to-day.

### Daily Tasks

| Task | When |
|---|---|
| Review new owner registrations | When a new restaurant applies |
| Approve or reject KYC | Within 24–48 hours of application |
| Suspend a restaurant | If a complaint is received or food safety issue found |
| View all orders | Any time — full order history across all restaurants |

### Admin Login
- Opens app → taps **"Admin"**
- Enters: Username + Password + 6-digit TOTP from Google Authenticator
- TOTP rotates every 30 seconds — provides two-factor security

### KYC Review Process
1. Admin sees a list of **Pending** owner applications
2. Clicks on an application to view full details (name, GSTIN, restaurant, documents)
3. Verifies GSTIN against government records (GST portal)
4. If satisfied → **Approve** → owner gets notified
5. If not satisfied → **Reject** with a written reason → owner gets notified with reason

---

## Key Business Rules

These rules govern how the app behaves for all users.

| Rule | Details |
|---|---|
| **Restaurant visibility** | Only **Active** restaurants appear in customer search. Pending and Suspended restaurants are hidden. |
| **Menu item visibility** | Only items with availability **ON** appear to customers. Owner can toggle this in real time (e.g. "Butter Naan sold out today"). |
| **GSTIN uniqueness** | One GSTIN = one owner account. Multiple restaurants under same GSTIN are all managed under one login. |
| **Price snapshot** | When a customer places an order, the prices are locked at that moment. If the owner changes prices later, old orders are not affected. |
| **Payment method** | Cash or UPI only. No in-app payment. Delivery person collects payment. |
| **Order cancellation** | To be defined in Terms & Conditions. |
| **No login to browse** | Customers can see all restaurants and menus without creating an account. Login only required to place an order. |
| **Admin is the gatekeeper** | No restaurant goes live without Admin approval. Admin can suspend any restaurant at any time. |

---

## What Happens When a Menu Item is Toggled Off?

This is an important real-time feature.

1. Owner logs in → goes to menu
2. Taps the toggle switch on "Butter Naan" → it turns grey (off)
3. **Immediately** (no delay), customers searching the menu no longer see Butter Naan
4. Owner turns the toggle back on → Butter Naan reappears for customers

**Use case:** Item runs out in the kitchen mid-day. Owner toggles it off. Customers don't see it and can't order it. No confusion or failed orders.

---

## Platform Phases

| Phase | What it covers | Status |
|---|---|---|
| **Phase 1 (Current)** | Admin KYC, Owner menu management, Customer pincode search + browse | 🟡 Sprint 6 of 8 complete |
| **Phase 1 (Remaining)** | Customer ordering, push notifications, APK on Play Store | ⬜ Sprints 7–8 |
| **Phase 2 (Future)** | Owner self-registration via app, email notifications, restaurant photos, ratings & reviews | ⬜ Planned |
| **Phase 3 (Future)** | Multiple cities, delivery tracking, in-app payment (Razorpay/PhonePe), analytics dashboard | ⬜ Planned |

---

## Owner Terms & Conditions (Draft Outline)

*Content to be written by Gurpreet. Suggested sections:*

1. **Eligibility** — Must have a valid GSTIN. Restaurant must be a legally registered food business.
2. **Listing Accuracy** — Owner is responsible for keeping menu items, prices, and availability accurate.
3. **Food Safety** — Owner is responsible for food hygiene and quality. GSR is a platform, not a food producer.
4. **Order Fulfilment** — Owner must accept or reject orders within 10 minutes. Consistent non-response leads to suspension.
5. **Payment** — Cash/UPI collected at delivery. GSR commission (if any) deducted monthly. (Phase 1: no commission.)
6. **Suspension Policy** — GSR Admin reserves the right to suspend any restaurant for verified complaints.
7. **Data Usage** — Customer order data is owned by GSR. Owner sees their own orders only.
8. **Termination** — Either party can terminate with 30 days' notice.

---

*This document covers the business and product flow only. For technical setup, deployment steps, and API details, refer to Runbook-Phase1.md.*
