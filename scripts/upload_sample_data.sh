#!/bin/bash
#
# Upload Sample Data to Search Indexes
# Populates indexes with Zava e-commerce sample data
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh" 2>/dev/null || true

log_step "Uploading Sample Data to Indexes"

API_VERSION="2024-07-01"

# Upload documents to index
upload_docs() {
    local index=$1
    local docs=$2
    
    log_info "Uploading documents to $index..."
    
    HTTP_CODE=$(curl -s -o /tmp/upload_response.json -w "%{http_code}" \
        -X POST "${SEARCH_ENDPOINT}/indexes/${index}/docs/index?api-version=${API_VERSION}" \
        -H "api-key: ${SEARCH_KEY}" \
        -H "Content-Type: application/json" \
        -d "$docs")
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        log_success "Uploaded documents to $index"
    else
        log_warn "Upload to $index may have issues (HTTP $HTTP_CODE)"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/upload_response.json
        fi
    fi
}

# HR Documents
HR_DOCS='{
    "value": [
        {
            "@search.action": "upload",
            "id": "hr-001",
            "title": "Remote Work Policy",
            "category": "Policies",
            "content": "Zava Remote Work Policy: Employees may work remotely up to 3 days per week with manager approval. Core collaboration hours are 10 AM - 3 PM in your local timezone. Equipment stipend of $500 provided for home office setup. VPN required for all remote access. Quarterly in-person team meetings are mandatory."
        },
        {
            "@search.action": "upload",
            "id": "hr-002",
            "title": "Health Benefits Overview",
            "category": "Benefits",
            "content": "Zava offers comprehensive health benefits: Medical (PPO and HMO options), Dental, Vision, and Mental Health coverage. Company pays 85% of premiums for employees, 60% for dependents. FSA and HSA accounts available. Annual wellness stipend of $1,200. Free gym membership at partner locations."
        },
        {
            "@search.action": "upload",
            "id": "hr-003",
            "title": "PTO and Leave Policy",
            "category": "Leave",
            "content": "Zava PTO Policy: 0-1 years: 15 days, 2-4 years: 20 days, 5+ years: 25 days, 10+ years: Unlimited with approval. Parental leave: 16 weeks fully paid. Bereavement: 5 days immediate family. Sick leave: Unlimited with documentation for 3+ consecutive days. Sabbatical: 4 weeks after 7 years of service."
        },
        {
            "@search.action": "upload",
            "id": "hr-004",
            "title": "Onboarding Guide",
            "category": "Onboarding",
            "content": "Welcome to Zava! Week 1: IT setup, HR paperwork, company overview. Week 2: Team introductions, role-specific training. Week 3: Buddy program pairing, first project assignment. Week 4: 30-day check-in with manager. All new hires receive ZavaBook Pro laptop, welcome kit, and branded swag."
        },
        {
            "@search.action": "upload",
            "id": "hr-005",
            "title": "Performance Review Process",
            "category": "Performance",
            "content": "Zava conducts bi-annual performance reviews in Q1 and Q3. Self-assessment due 2 weeks before review. 360 feedback collected from peers and cross-functional partners. Rating scale: Exceeds (5), Meets+ (4), Meets (3), Developing (2), Below (1). Compensation adjustments tied to Q1 review. Development plans created in Q3 review."
        },
        {
            "@search.action": "upload",
            "id": "hr-006",
            "title": "Stock Options and Equity",
            "category": "Compensation",
            "content": "Zava equity program: New hire grants vest over 4 years with 1-year cliff. Annual refresh grants based on performance (typically 25-50% of initial grant). Exercise window: 90 days post-departure for unvested, 10 years for vested. Stock options valued at latest 409A valuation. Equity refreshes awarded in February."
        },
        {
            "@search.action": "upload",
            "id": "hr-007",
            "title": "Learning and Development",
            "category": "Development",
            "content": "Professional development at Zava: $5,000 annual learning budget per employee. Access to LinkedIn Learning, Coursera, and internal Zava Academy. Conference attendance: Up to 2 conferences per year. Internal mobility program: Explore new roles after 18 months. Mentorship matching program available."
        },
        {
            "@search.action": "upload",
            "id": "hr-008",
            "title": "Company Holidays 2026",
            "category": "Leave",
            "content": "Zava 2026 Holiday Schedule: New Year Day (Jan 1), MLK Day (Jan 19), Presidents Day (Feb 16), Memorial Day (May 25), Independence Day (Jul 3-4), Labor Day (Sep 7), Thanksgiving (Nov 26-27), Winter Break (Dec 24-31). Floating holidays: 2 days to use anytime. Office closed Dec 24 - Jan 1."
        }
    ]
}'

# Products Documents
PRODUCTS_DOCS='{
    "value": [
        {
            "@search.action": "upload",
            "id": "prod-001",
            "title": "ZavaBook Pro 16\"",
            "category": "Laptops",
            "content": "ZavaBook Pro 16-inch: M4 Pro chip, 18-core CPU, 16GB unified memory, 512GB SSD. 16.2-inch Liquid Retina XDR display, 3456x2234 resolution. 22-hour battery life. MagSafe 3, 3x Thunderbolt 4, HDMI, SD card slot. Price: $1,899.99. Stock: 450 units. SKU: ZBP-2026-PRO. Best for creative professionals and developers."
        },
        {
            "@search.action": "upload",
            "id": "prod-002",
            "title": "SoundMax Elite Headphones",
            "category": "Audio",
            "content": "SoundMax Elite wireless over-ear headphones: Active noise cancellation with 3 modes. 40mm custom drivers, 20Hz-40kHz frequency response. 30-hour battery, quick charge (10 min = 3 hours). Bluetooth 5.3, multipoint connection. Foldable design, premium memory foam cushions. Price: $349.99. Stock: 1,200 units. SKU: SMX-ELITE-BLK."
        },
        {
            "@search.action": "upload",
            "id": "prod-003",
            "title": "ProFit Watch Series 5",
            "category": "Wearables",
            "content": "ProFit Watch Series 5: Advanced health monitoring with ECG, blood oxygen, continuous heart rate. Built-in GPS, cellular option. 45mm case, always-on AMOLED display. 5ATM water resistance, swim tracking. Sleep analysis with smart alarm. 18-hour battery. Price: $299.99 (GPS), $399.99 (Cellular). Stock: 800 units."
        },
        {
            "@search.action": "upload",
            "id": "prod-004",
            "title": "ZavaTab Pro 12.9\"",
            "category": "Tablets",
            "content": "ZavaTab Pro 12.9-inch tablet: M3 chip, 8GB RAM, 256GB storage. 12.9-inch Liquid Retina XDR, ProMotion 120Hz. Face ID, USB-C with Thunderbolt. Compatible with ZavaPencil Pro and Magic Keyboard. 10-hour battery. Price: $1,099.99. Stock: 600 units. SKU: ZTP-129-M3. Perfect for artists and mobile professionals."
        },
        {
            "@search.action": "upload",
            "id": "prod-005",
            "title": "ZavaKeys Wireless Keyboard",
            "category": "Accessories",
            "content": "ZavaKeys wireless mechanical keyboard: Low-profile switches, tactile feedback. RGB backlit with customizable zones. Bluetooth + 2.4GHz dongle. Multi-device switching (up to 3). Rechargeable, 200-hour battery. Aluminum frame, compact tenkeyless layout. Price: $129.99. Stock: 2,500 units. SKU: ZK-WL-TKL."
        },
        {
            "@search.action": "upload",
            "id": "prod-006",
            "title": "PowerMax 100W Charger",
            "category": "Accessories",
            "content": "PowerMax 100W GaN charger: 4 ports (2x USB-C PD, 2x USB-A). Charges laptop, phone, tablet, watch simultaneously. Foldable prongs, travel-friendly. Universal voltage 100-240V. Smart power distribution. Price: $79.99. Stock: 4,000 units. SKU: PM-100W-4P. Compact and powerful for all your devices."
        },
        {
            "@search.action": "upload",
            "id": "prod-007",
            "title": "ZavaCam 4K Pro",
            "category": "Cameras",
            "content": "ZavaCam 4K Pro webcam: 4K/30fps or 1080p/60fps. Auto-framing AI, background blur. Noise-canceling dual mics. Built-in privacy shutter. USB-C plug and play. Works with Zoom, Teams, Google Meet. Field of view: 90° adjustable. Price: $199.99. Stock: 1,800 units. SKU: ZC-4K-PRO. Studio quality for remote work."
        },
        {
            "@search.action": "upload",
            "id": "prod-008",
            "title": "ZavaPods Ultra",
            "category": "Audio",
            "content": "ZavaPods Ultra true wireless earbuds: Adaptive ANC, transparency mode. 6-hour battery, 30 hours with case. Spatial audio with head tracking. IPX4 sweat resistance. Touch controls, Hey Zava voice activation. Custom EQ in app. Price: $249.99. Stock: 3,500 units. SKU: ZPU-2026-WHT. Immersive sound, all-day comfort."
        }
    ]
}'

# Marketing Documents
MARKETING_DOCS='{
    "value": [
        {
            "@search.action": "upload",
            "id": "mkt-001",
            "title": "Summer Sale 2026 Campaign",
            "category": "Campaigns",
            "content": "Summer Sale 2026 runs June 15 - July 15. Discounts: Electronics 20-30% off, Fashion 25-40% off, Home 15-25% off. Promotional codes: SUMMER20 (20% off $100+), SUMMER30 (30% off $200+). Email blast schedule: June 14 teaser, June 15 launch, June 22 mid-campaign, July 10 last chance. Target: $5M revenue, 50K new customers."
        },
        {
            "@search.action": "upload",
            "id": "mkt-002",
            "title": "Holiday Campaign Strategy",
            "category": "Campaigns",
            "content": "Holiday 2026 Campaign: Theme \"Give the Gift of Innovation\". Black Friday (Nov 27): 40% off sitewide. Cyber Monday (Nov 30): Tech deals focus. 12 Days of Deals (Dec 13-24). Gift guides: Tech Lover, Home Chef, Fitness Fan, Budget-Friendly. Influencer partnerships: 25 creators, unboxing content. Budget: $2M total spend."
        },
        {
            "@search.action": "upload",
            "id": "mkt-003",
            "title": "Brand Guidelines 2026",
            "category": "Brand",
            "content": "Zava Brand Guidelines: Primary color Zava Blue (#0066CC), secondary Electric Orange (#FF6600). Typography: Zava Sans for headlines, Inter for body. Voice: Friendly, innovative, trustworthy. Logo clear space: 2x height of Z. Never distort, recolor, or add effects to logo. Photography style: Clean, lifestyle-focused, diverse representation."
        },
        {
            "@search.action": "upload",
            "id": "mkt-004",
            "title": "Social Media Playbook",
            "category": "Social",
            "content": "Zava Social Media Guidelines: Instagram (2x daily, visual product focus). TikTok (3x daily, trends and behind-scenes). Twitter/X (4x daily, news and support). LinkedIn (1x daily, company culture and B2B). YouTube (2x weekly, tutorials and reviews). Response time: 2 hours for complaints, 24 hours for general. Hashtags: #ZavaLife #ZavaTech."
        },
        {
            "@search.action": "upload",
            "id": "mkt-005",
            "title": "Email Marketing Metrics Q4 2025",
            "category": "Analytics",
            "content": "Q4 2025 Email Performance: Sent 12.5M emails, 22.3% open rate (industry avg 19.8%), 3.8% CTR (industry avg 2.6%), 0.4% conversion rate. Top performing: Black Friday (45% open rate), Product Launch (38% open rate). Revenue attributed: $4.2M. Unsubscribe rate: 0.2%. Best send time: Tuesday 10 AM EST."
        },
        {
            "@search.action": "upload",
            "id": "mkt-006",
            "title": "Influencer Partnership Program",
            "category": "Partnerships",
            "content": "Zava Influencer Program 2026: Tier 1 (1M+ followers): 15% commission, free products, exclusive access. Tier 2 (100K-1M): 10% commission, quarterly products. Micro (10K-100K): 8% commission, performance bonuses. Current roster: 47 Tier 1, 312 Tier 2, 1,847 micro. Q4 2025 influencer revenue: $4.2M. Top category: Electronics (TechTubers)."
        },
        {
            "@search.action": "upload",
            "id": "mkt-007",
            "title": "Competitor Analysis 2026",
            "category": "Research",
            "content": "Competitive Landscape 2026: Amazon - Leader in delivery speed, Prime ecosystem. Best Buy - Strong in-store experience, Geek Squad services. Walmart - Price leader, grocery crossover. Zava differentiation: Superior customer service (89% satisfaction), curated product selection, exclusive brands, loyalty rewards. Market share: 8.2% (up from 6.7% in 2025)."
        },
        {
            "@search.action": "upload",
            "id": "mkt-008",
            "title": "Content Calendar Q1 2026",
            "category": "Content",
            "content": "Q1 2026 Content Plan: January - New Year New Gear (Jan 2-15), CES coverage, Winter Clearance (Jan 16-31). February - Valentine Gift Guide (Feb 1-14), Presidents Day Sale (Feb 15-19). March - Spring Refresh (Mar 1-15), St Patricks Flash Sale (Mar 17). Blogs: 3x weekly (Mon reviews, Wed how-tos, Fri trends). Video: 4 YouTube/month, 20 TikTok/week."
        }
    ]
}'

# SharePoint HR Documents (indexed separately)
SHAREPOINT_HR_DOCS='{
    "value": [
        {
            "@search.action": "upload",
            "id": "sp-hr-001",
            "title": "Promotion Guidelines",
            "category": "HR Policy",
            "content": "ZAVA PROMOTION GUIDELINES. Eligibility: Minimum 12 months in current role, Meets/Exceeds performance rating in last 2 cycles, manager recommendation. Promotion Cycles: Q1 Engineering/Product/Design, Q2 Sales/Marketing, Q3 Operations/Customer Success, Q4 All departments (exceptional). Compensation: IC Level 10-15% increase, Management transition 15-20%. Career Ladder: IC Track (Associate → IC → Senior → Staff → Principal → Distinguished), Management Track (Manager → Director → VP → C-Level)."
        },
        {
            "@search.action": "upload",
            "id": "sp-hr-002",
            "title": "PTO Allowance Details",
            "category": "HR Policy",
            "content": "ZAVA DETAILED PTO POLICY. By Tenure: 0-1 years 15 days, 2-4 years 20 days, 5-9 years 25 days, 10+ years Unlimited with approval. Additional Leave: Parental 16 weeks paid, Bereavement 5 days immediate family, Jury Duty paid, Volunteer 2 days/year, Sabbatical 4 weeks after 7 years. Request Process: Submit via Workday 2 weeks advance, manager approval within 48 hours. Blackout periods: Last 2 weeks of quarter for customer-facing teams. Carryover: Max 5 days to following year, must use by March 31."
        },
        {
            "@search.action": "upload",
            "id": "sp-hr-003",
            "title": "Compensation Bands 2026",
            "category": "Compensation",
            "content": "ZAVA COMPENSATION BANDS 2026. Engineering: L1 $80-100K, L2 $100-130K, L3 $130-170K, L4 $170-220K, L5 $220-280K. Product: Associate PM $85-105K, PM $110-140K, Senior PM $140-180K, Director $180-240K. Sales: SDR $50K base + $30K OTE, AE $80K + $80K OTE, Senior AE $100K + $150K OTE, Enterprise AE $120K + $200K OTE. Equity: 4-year vest, 1-year cliff, annual refresh based on performance. Geographic tiers: SF/NYC/Seattle base rate, Austin/Denver/Boston 90%, Remote other 80%."
        },
        {
            "@search.action": "upload",
            "id": "sp-hr-004",
            "title": "Employee Handbook Summary",
            "category": "General",
            "content": "ZAVA EMPLOYEE HANDBOOK. Code of Conduct: Integrity, respect, protect confidential info, report conflicts of interest. Expenses: Travel per diem by city, meals up to $75/day, flights economy under 6hr or business 6+hr, hotels up to $250/night major metros. Equipment: MacBook Pro or Dell XPS choice, up to 2 monitors, headset and webcam provided. Remote Work: Hybrid 2 days in office minimum, fully remote quarterly gatherings required. Core hours 10AM-3PM for meetings. Social Media: Avoid discussing confidential info, only authorized spokespersons represent company."
        }
    ]
}'

# Upload all documents
upload_docs "index-hr" "$HR_DOCS"
upload_docs "index-products" "$PRODUCTS_DOCS"
upload_docs "index-marketing" "$MARKETING_DOCS"
upload_docs "index-hr-sharepoint" "$SHAREPOINT_HR_DOCS"

# Create marketing blob container and upload data
log_info "Creating marketing blob container..."
az storage container create --name marketing --account-name "$STORAGE_ACCOUNT" --auth-mode login 2>/dev/null || true

# Create marketing blob files
mkdir -p /tmp/marketing-blob

cat > /tmp/marketing-blob/influencer_partnerships.json << 'EOF'
{
  "title": "Zava Influencer Partnership Program 2026",
  "category": "influencer-marketing",
  "content": "Zava's influencer partnership program connects with content creators across YouTube, TikTok, and Instagram. Tier 1 partners (1M+ followers) receive 15% commission on sales, free products, and exclusive early access. Tier 2 partners (100K-1M followers) receive 10% commission and quarterly product bundles. Micro-influencers (10K-100K) receive 8% commission with performance bonuses. Current active partnerships: 47 Tier 1, 312 Tier 2, 1,847 micro-influencers. Q4 2025 influencer-driven revenue: $4.2M. Top performing category: Electronics (ZavaBook Pro campaign with TechTuber generated 23,000 direct sales)."
}
EOF

cat > /tmp/marketing-blob/content_calendar_q1_2026.json << 'EOF'
{
  "title": "Q1 2026 Content Calendar",
  "category": "content-planning",
  "content": "January: New Year New Gear campaign (Jan 2-15), Winter Clearance (Jan 16-31). February: Valentine's Gift Guide (Feb 1-14), Presidents Day Sale (Feb 15-19), Spring Preview (Feb 20-28). March: Spring Forward Home Refresh (Mar 1-15), St. Patrick's Day Flash Sale (Mar 17), End of Quarter Push (Mar 20-31). Blog posts: 3x weekly (Monday product reviews, Wednesday how-tos, Friday trend roundups). Social media: 2x daily Instagram, 3x daily TikTok, 1x daily LinkedIn. Email cadence: 2x weekly promotional, 1x weekly newsletter. Video content: 4 YouTube reviews per month, 20 TikTok shorts per week."
}
EOF

cat > /tmp/marketing-blob/customer_testimonials.json << 'EOF'
{
  "title": "Featured Customer Testimonials",
  "category": "social-proof",
  "content": "Sarah M., Austin TX: 'The ZavaBook Pro changed how I work remotely. Battery lasts all day and the display is gorgeous. 5 stars!' Rating: 5/5. James K., Seattle WA: 'Ordered the SoundMax headphones on Monday, arrived Wednesday. Noise cancellation is incredible for my commute.' Rating: 5/5. Maria L., Miami FL: 'Third time ordering from Zava. Customer service helped me with a return, no questions asked. Will keep coming back.' Rating: 5/5. David R., Chicago IL: 'The ProFit smartwatch tracks my workouts better than my old Fitbit. Heart rate accuracy is spot-on.' Rating: 4/5. Current NPS score: 72. Review response rate: 94% within 24 hours."
}
EOF

cat > /tmp/marketing-blob/market_research_electronics.json << 'EOF'
{
  "title": "Consumer Electronics Market Research - January 2026",
  "category": "market-research",
  "content": "Key findings from Zava's Q4 2025 consumer electronics survey (n=5,000). Purchase drivers: 1) Price (78%), 2) Reviews (71%), 3) Brand reputation (54%), 4) Free shipping (52%), 5) Return policy (48%). Emerging trends: Sustainable packaging influences 34% of Gen Z buyers. Wireless charging now expected as standard feature (up from 23% in 2024 to 67% in 2025). Average customer research time before purchase: 4.2 days for items over $200. Competitor analysis: Amazon leads in delivery speed, Best Buy in in-store experience, Zava leads in customer service satisfaction (89% vs industry average 71%). Recommended focus areas: Same-day delivery expansion, enhanced AR product previews."
}
EOF

cat > /tmp/marketing-blob/press_release_expansion.json << 'EOF'
{
  "title": "Press Release: Zava Announces European Expansion",
  "category": "press-release",
  "content": "FOR IMMEDIATE RELEASE - January 15, 2026. Zava, the leading online marketplace for consumer electronics and lifestyle products, today announced its expansion into the European market with dedicated fulfillment centers in Dublin, Ireland and Rotterdam, Netherlands. The expansion will enable 2-day delivery to 90% of EU customers. 'This represents a major milestone in Zava's mission to deliver quality products globally,' said CEO Amanda Chen. Initial European catalog includes 50,000 SKUs with plans to reach 200,000 by end of 2026. The company will hire 500 employees across both locations. European operations expected to contribute 15% of total revenue by Q4 2026. Media contact: press@zava.com."
}
EOF

# Upload blob files
log_info "Uploading marketing blob files..."
for file in /tmp/marketing-blob/*.json; do
    az storage blob upload --account-name "$STORAGE_ACCOUNT" --container-name marketing \
        --file "$file" --name "$(basename $file)" --auth-mode login --overwrite 2>/dev/null || true
done

log_success "Sample data uploaded to all indexes and blob storage"
