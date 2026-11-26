.pragma library

function escapeHtml(text) {
    return String(text || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

// Compute fuzzy + prefix + word-boundary/acronym match score and matched character indices in `name`.
// Returns null if `query` does not match `name` or `keywords`.
function scoreCandidate(query, name, keywords, frecencyCount) {
    const q = String(query || "").trim().toLowerCase();
    const title = String(name || "");
    const lowerTitle = title.toLowerCase();
    const frecency = Math.min(40, Number(frecencyCount || 0) * 4);

    if (q.length === 0) {
        return { score: frecency, indices: [] };
    }

    // 1. Subsequence fuzzy match against the display name with position & continuity bonuses
    let qi = 0;
    let score = 0;
    let consecutive = 0;
    const indices = [];

    for (let ti = 0; ti < lowerTitle.length && qi < q.length; ++ti) {
        if (lowerTitle.charCodeAt(ti) === q.charCodeAt(qi)) {
            indices.push(ti);
            let pts = 10;
            if (ti === 0) {
                pts += 26;
            } else {
                const prev = lowerTitle.charAt(ti - 1);
                if (prev === " " || prev === "-" || prev === "_" || prev === "/" || prev === ".") {
                    pts += 20; // Word-start / acronym bonus (e.g. "ss" -> System Settings)
                } else if (title.charAt(ti) >= "A" && title.charAt(ti) <= "Z") {
                    pts += 14; // CamelCase boundary bonus
                }
            }
            if (consecutive > 0) {
                pts += 12 + Math.min(10, consecutive * 2);
            }
            // Slight preference for earlier matches
            pts -= Math.min(6, Math.floor(ti / 4));
            score += pts;
            consecutive += 1;
            qi += 1;
        } else {
            consecutive = 0;
        }
    }

    if (qi === q.length) {
        if (lowerTitle === q) {
            score += 120;
        } else if (lowerTitle.startsWith(q)) {
            score += 65;
        }
        // Shorter, tighter matches win ties
        score -= Math.min(18, Math.floor((lowerTitle.length - q.length) / 2));
        return { score: score + frecency, indices: indices };
    }

    // 2. Fallback: match against keywords / description / command alias (lower priority than title match)
    const kw = String(keywords || "").toLowerCase();
    if (kw.length > 0) {
        let kqi = 0;
        for (let ki = 0; ki < kw.length && kqi < q.length; ++ki) {
            if (kw.charCodeAt(ki) === q.charCodeAt(kqi)) {
                kqi += 1;
            }
        }
        if (kqi === q.length) {
            const substrBonus = kw.indexOf(q) >= 0 ? 25 : 0;
            return { score: 15 + substrBonus + frecency, indices: [] };
        }
    }

    return null;
}

// Highlight matched indices in frost-teal #88c0d0 using safe HTML escaping
function formatHighlighted(name, indices) {
    const text = String(name || "");
    if (!indices || indices.length === 0) {
        return escapeHtml(text);
    }
    const set = {};
    for (let i = 0; i < indices.length; ++i) {
        set[indices[i]] = true;
    }
    let out = "";
    let inSpan = false;
    for (let i = 0; i < text.length; ++i) {
        const ch = escapeHtml(text.charAt(i));
        const hit = Boolean(set[i]);
        if (hit && !inSpan) {
            out += '<font color="#88c0d0"><b>';
            inSpan = true;
        } else if (!hit && inSpan) {
            out += "</b></font>";
            inSpan = false;
        }
        out += ch;
    }
    if (inSpan) {
        out += "</b></font>";
    }
    return out;
}

// Filter, score, and rank an array of items: { id, name, icon, keywords, kind, ... }
function rankItems(items, query, launchCounts, maxResults) {
    const q = String(query || "").trim();
    const counts = launchCounts || {};
    const limit = maxResults || 8;
    const scored = [];

    for (let i = 0; i < items.length; ++i) {
        const item = items[i];
        if (!item || !item.name) {
            continue;
        }
        const count = Number(counts[item.id] || 0);
        if (q.length === 0) {
            // Empty state: prioritize frequently launched items, then default priority items
            const basePriority = Number(item.defaultRank || 0);
            if (count > 0 || basePriority > 0) {
                scored.push({
                    item: item,
                    score: count * 20 + basePriority,
                    indices: [],
                });
            }
        } else {
            const match = scoreCandidate(q, item.name, item.keywords, count);
            if (match !== null) {
                const isPrefix = item.name.toLowerCase().startsWith(q.toLowerCase());
                const boost = isPrefix ? Number(item.prefixBoost || 0) : 0;
                scored.push({
                    item: item,
                    score: match.score + boost,
                    indices: match.indices,
                });
            }
        }
    }

    // If empty query produced fewer than `limit` items (e.g. brand-new install), pad alphabetically with apps
    if (q.length === 0 && scored.length < limit) {
        const seen = {};
        for (let i = 0; i < scored.length; ++i) {
            seen[scored[i].item.id] = true;
        }
        for (let i = 0; i < items.length && scored.length < limit; ++i) {
            const item = items[i];
            if (item && item.kind === "app" && !seen[item.id]) {
                seen[item.id] = true;
                scored.push({ item: item, score: -1, indices: [] });
            }
        }
    }

    scored.sort(function(a, b) {
        if (b.score !== a.score) {
            return b.score - a.score;
        }
        return a.item.name.localeCompare(b.item.name);
    });

    const result = [];
    const cap = Math.min(limit, scored.length);
    for (let i = 0; i < cap; ++i) {
        const entry = scored[i];
        result.push({
            id: entry.item.id,
            name: entry.item.name,
            displayHtml: formatHighlighted(entry.item.name, entry.indices),
            icon: entry.item.icon,
            kind: entry.item.kind,
            appRow: entry.item.appRow !== undefined ? entry.item.appRow : -1,
            actionId: entry.item.actionId || "",
            command: entry.item.command || "",
        });
    }
    return result;
}
