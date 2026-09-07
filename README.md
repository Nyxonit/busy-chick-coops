# Busy Chick Coops — storefront

One file, no build step, no framework. `index.html` is the whole store:
HTML + CSS + JavaScript in a single page. Open it in a browser and it works.

## What's in it

- **Built to order** — 3 coops + 1 greenhouse. Buyer picks one → "Make it yours" page
  (color, add-ons, free-text changes) → cart → address → payment.
- **Equipment, Feed & bedding, Eggs & birds** — paid in full, add straight to cart.
- **Payment page** — three ways to pay on any order over $500:
  - 50% NON-REFUNDABLE deposit (built items), balance at delivery
  - Pay in full
  - In-house payment plan: 25% down, then 3 or 6 monthly payments.
    Plan price is 5% (3 mo) / 10% (6 mo) above cash price. Delivered after the last
    payment clears. This is a layaway plan, NOT a loan — never call the markup "interest".
- **Payment methods** — Stripe link per product (cards, Apple/Google Pay, Cash App Pay,
  Link, ACH, Affirm, Klarna, Afterpay), plus PayPal.Me and Zelle instructions.
- Light/dark theme, cart saved in the browser (localStorage), mobile layout.

## Everything you'd edit is at the top of the `<script>` block

| Setting | What it does |
|---|---|
| `STORE_NAME`, `STORE_TAGLINE` | Name in the header, footer, and browser tab |
| `PAY.paypal` | Your PayPal.Me link, e.g. `https://paypal.me/busychickcoops` |
| `PAY.zelle` | Name + phone/email registered with Zelle |
| `PLAN` | Down payment %, plan lengths, markup per length, minimum order |
| `PRODUCTS` | The whole catalog — see field guide in the code comments |
| `CATS` / `SECTION` | Category chips and section headers |

Prices are in **cents** (`240000` = $2,400.00).

### Per-product payment links
Each product has `stripe: ''`. Built-to-order items also have `stripeFull: ''` and
`stripePlan: ''`. Until a link is filled in, the pay button shows a "not connected" placeholder.

## Connecting Stripe (no code)

1. Stripe Dashboard → **Settings → Payment methods** → turn on cards, Apple Pay, Google Pay,
   Link, Cash App Pay, ACH Direct Debit, Affirm, Klarna, Afterpay.
2. **Payment Links → + New**. One link per product at its full price.
   For each built-to-order item make three: full price, 50% deposit, 25% plan down payment.
   Turn on *Collect customers' addresses* and *Let customers adjust quantity*.
3. Paste each link into the matching `stripe` / `stripeFull` / `stripePlan` field.
4. Stripe asks for a website during onboarding — give it the live domain (below), not
   the claude.ai draft link.

## Photos
Each product accepts `img: 'photos/coop-m.jpg'` (or a full URL / data URL). When set, the
photo replaces the line drawing. Use your **own** photos of your builds for the structures;
use manufacturer photos for equipment once you're set up as a dealer.

## Deploying (free)

**Cloudflare Pages** (recommended) or Netlify:
1. Buy the domain (e.g. busychickcoops.com) — Cloudflare Registrar or Namecheap, ~$10/yr.
2. Cloudflare Dashboard → Workers & Pages → Create → Pages → **Upload assets**.
   Upload this folder (`index.html` + any `photos/`). It gets a `*.pages.dev` URL immediately.
3. Pages project → Custom domains → add `busychickcoops.com`. Done; HTTPS is automatic.

To update the site later, upload the folder again.

## Things still to decide / do (not code)
- Real prices once materials and suppliers are costed
- Delivery radius (currently says "within 60 miles")
- Photos of the first coop build
- File a DBA for "Busy Chick Coops" under Project Chick LLC if you want the name on receipts
- Monthly payment-plan collection: send a Stripe payment link or invoice each month
