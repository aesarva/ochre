---
version: 1
slug: "site-index-html"
primary_target: "site/index.html"
related_targets: []
---

# Surface brief: StatusApp landing (site/index.html)

Scope: public landing page for StatusApp. Mode: Persuade. Bilingual RU/EN with a switcher; desktop, tablet, phone.
Audience: Apple Silicon Mac owners, technical and everyday. Action: download the free notarized DMG (macOS 26+). Proof: the die map itself (simulated, labeled), real popover renders from the app, measured footprint (0.7% CPU, 13 MB, M5 Pro, popover closed). No testimonials, counts, prices beyond "free", or source links.
Constraints: gray-mustard palette pinned by the user; colour still means load/heat; static HTML/CSS/JS, relative URLs, no build step; DMG is served beside the page.
Memorable moment: the board flips — core cells flip as load changes every 2 s, and switching language flips every board label.
Open: hosting provider; final DMG file name/URL.

## Direction contract

THESIS: The page is a station departure board for your Mac's chip: cores, processes and labels are split-flap tiles that flip with load. It refuses the category default of a dark hero over a glossy popover screenshot and a row of feature cards.

OWN-WORLD: Graphite board housing on a darker ground; matte charcoal flap tiles split by a hairline; warm off-white condensed flap glyphs with tabular figures; mustard is the only chroma — light mustard for warm, deep mustard for hot, rust only for >90% heat. Set text is a calm Cyrillic-capable grotesk; flaps use a condensed grotesk. Section boards are framed housings with column headers; no cards, no eyebrows, no glass.

STORY: Visitor sees their chip as a live board, understands "this shows which cores are hot, right in the menu bar", sees it is light, real (actual app renders) and free, and downloads.

FIRST VIEWPORT: Flap wordmark top-left, RU/EN flap switch top-right. One wide board: left column headline (3 lines), one-line subhead, mustard "Download for macOS 26" button with "Free · 13 MB of memory"; below, Super row of 6 large flap cells and Performance row of 12 small cells with load numbers. Right column: departures-style process rows (Xcode largest), then CPU temperature in big flaps. Caption marks the board as a simulated M5 Pro.

FORM: Split-flap departure board (Solari), candidate 5 of 7 on the grounded list; seed key 7f87b1fd. Raises: empty flaps as active space (ikebana); greys carry everything, mustard only for load or the main action (HyperCard); heat scale as a stepped test strip (darkroom); process rank by row size only (fight poster). Signature interaction: language switch and load updates flip the flaps; reduced motion swaps values without flipping.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
