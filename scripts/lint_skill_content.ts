#!/usr/bin/env npx tsx

/**
 * Anti-regression lint for superpowers-api-platform.
 *
 * Two responsibilities:
 *  1. Enforce SKILL.md structural sections + decent description.
 *  2. Reject API Platform pre-4.3 patterns anywhere in skills/, agents/, commands/, docs/,
 *     EXCEPT inside the dedicated `api-platform-upgrade/` skill which documents the migration.
 *     Also flags Symfony < 7.4 mentions that would suggest the plugin still supports older
 *     versions.
 */

import * as fs from 'fs';
import * as path from 'path';

const PLUGIN_ROOT = path.resolve(__dirname, '..');
const SKILLS = path.join(PLUGIN_ROOT, 'skills');

const requiredSections = [
  '## Use when',
  '## Default workflow',
  '## Guardrails',
  '## Output contract',
  '## References',
];

interface Rule {
  id: string;
  pattern: RegExp;
  message: string;
  // Skip the rule for files matching any of these path fragments
  allowIn?: string[];
}

const LEGACY_RULES: Rule[] = [
  {
    id: 'apifilter-attribute',
    pattern: /#\[\s*ApiFilter\s*\(/,
    message:
      '#[ApiFilter] is deprecated in API Platform 4.2+ (removed in 5.0). Use `parameters: [new QueryParameter(filter: new ExactFilter(), property: ...)]`.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'abstract-filter-extend',
    pattern: /extends\s+AbstractFilter\b/,
    message:
      'Inheriting AbstractFilter is deprecated. Implement FilterInterface + BackwardCompatibleFilterDescriptionTrait + JsonSchemaFilterInterface + OpenApiParameterFilterInterface.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'openapi-context',
    pattern: /openapiContext\s*:/,
    message:
      'openapiContext is deprecated. Use `openapi: new \\ApiPlatform\\OpenApi\\Model\\Operation(...)` (Rector: lyrixx/rector-apip-openapi).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'hydra-prefix',
    pattern: /["']hydra:(member|totalItems|view|next|previous|first|last)["']/,
    message:
      'API Platform 4.x defaults to hydra_prefix: false. Use `member` / `totalItems` / `view` / `next` etc. without the `hydra:` prefix.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'validation-exception-symfony-namespace',
    pattern: /ApiPlatform\\Symfony\\Validator\\Exception\\ValidationException/,
    message:
      'ValidationException was moved to ApiPlatform\\Validator\\Exception\\ValidationException in API Platform 4.x.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'serializer-aware-provider',
    pattern: /\bSerializerAwareProviderInterface\b/,
    message: 'SerializerAwareProviderInterface is deprecated since 4.2 and removed in 5.0.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'serializable-provider',
    pattern: /\bSerializableProvider\b/,
    message: 'SerializableProvider is deprecated since 4.2 and removed in 5.0.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-bc-layer',
    pattern: /event_listeners_backward_compatibility_layer/,
    message: '`event_listeners_backward_compatibility_layer` was a 3.x legacy flag — must not appear in 4.x projects.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-inflector',
    pattern: /keep_legacy_inflector/,
    message: '`keep_legacy_inflector` was a 3.x legacy flag — must not appear in 4.x projects.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-core-namespace',
    pattern: /ApiPlatform\\Core\\/,
    message: 'The ApiPlatform\\Core\\ namespace is 3.x. In 4.x, use ApiPlatform\\... (no Core segment).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-search-filter-class',
    pattern: /\bSearchFilter::class\b|use ApiPlatform\\Doctrine\\Orm\\Filter\\SearchFilter\b/,
    message: 'SearchFilter is legacy. Use ExactFilter / PartialSearchFilter / IriFilter (4.3 modern pattern).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-order-filter-class',
    pattern: /\bOrderFilter::class\b|use ApiPlatform\\Doctrine\\Orm\\Filter\\OrderFilter\b/,
    message: 'OrderFilter is legacy. Use SortFilter (4.3 — supports `nullsComparison`).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-date-filter-class',
    pattern: /\bDateFilter::class\b|use ApiPlatform\\Doctrine\\Orm\\Filter\\DateFilter\b/,
    message: 'DateFilter is legacy. Use ComparisonFilter (4.3 — `gt`/`gte`/`lt`/`lte`/`ne`).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-range-filter-class',
    pattern: /\bRangeFilter::class\b|use ApiPlatform\\Doctrine\\Orm\\Filter\\RangeFilter\b/,
    message: 'RangeFilter is legacy. Use ComparisonFilter (4.3).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-numeric-filter-class',
    pattern: /\bNumericFilter::class\b|use ApiPlatform\\Doctrine\\Orm\\Filter\\NumericFilter\b/,
    message: 'NumericFilter is legacy. Use ExactFilter / ComparisonFilter (4.3).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'legacy-boolean-filter-class',
    pattern: /\bBooleanFilter::class\b|use ApiPlatform\\Doctrine\\Orm\\Filter\\BooleanFilter\b/,
    message: 'BooleanFilter is legacy. Use ExactFilter (it accepts true/false/1/0).',
    allowIn: ['skills/api-platform-upgrade/'],
  },
  {
    id: 'symfony-pre-7-4',
    pattern: /\bSymfony\s+(3\.|4\.|5\.|6\.0|6\.1|6\.2|6\.3|6\.4|7\.0|7\.1|7\.2|7\.3)\b/i,
    message: 'This plugin targets Symfony 7.4 LTS+ only. Older versions should not appear as supported.',
    allowIn: ['skills/api-platform-upgrade/'],
  },
];

interface Finding {
  file: string;
  line: number;
  ruleId: string;
  message: string;
  excerpt: string;
}

/**
 * Heuristic to detect prose that frames the legacy pattern as deprecated/legacy/to-be-removed.
 * Such mentions are allowed anywhere — the lint only blocks USE of the pattern, not WARNINGS
 * against it.
 */
const META_MENTION_REGEX =
  /\b(deprecated|legacy|do not use|don['’]t use|never use|remove[ds]?|to migrate|migrate from|migrate code|forbidden|avoid|out of scope|in legacy|3\.x|pre-4\.3|deprec|former|formerly|previously|warn against|replaced by|equivalent of|equivalence|migration|rector|upgrade|anti-regression|anti-pattern[s]?|reject(s|ed)?|must be absent|must not appear|absent|warn(s|ing)?|flag(s|ged)?|in new code|new code|checklist|self-audit|self audit)\b|❌|\[Y\/N\]/i;

let failed = false;

// ============================================
// 1. SKILL STRUCTURAL CHECKS
// ============================================

function lintSkillStructure(): void {
  if (!fs.existsSync(SKILLS)) return;
  for (const entry of fs.readdirSync(SKILLS, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const file = path.join(SKILLS, entry.name, 'SKILL.md');
    if (!fs.existsSync(file)) continue;
    const content = fs.readFileSync(file, 'utf8');

    for (const section of requiredSections) {
      if (!content.includes(section)) {
        console.error(`[missing-section] ${entry.name}: ${section}`);
        failed = true;
      }
    }

    const desc = (content.match(/\ndescription:\s*(.+)\n/) || [])[1] || '';
    if (desc.length < 40) {
      console.error(`[weak-description] ${entry.name}: description too short`);
      failed = true;
    }
    if (/Use when .*\b(skill|symfony)\b/i.test(desc)) {
      console.error(`[weak-description] ${entry.name}: generic description`);
      failed = true;
    }
  }
}

// ============================================
// 2. LEGACY-PATTERN ANTI-REGRESSION
// ============================================

function walk(dir: string, out: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === 'vendor') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, out);
    } else if (entry.isFile()) {
      out.push(full);
    }
  }
  return out;
}

function isAllowed(relFile: string, allowIn?: string[]): boolean {
  if (!allowIn || allowIn.length === 0) return false;
  return allowIn.some((fragment) => relFile.includes(fragment));
}

function lintLegacyPatterns(): Finding[] {
  const findings: Finding[] = [];
  const files = walk(PLUGIN_ROOT);

  for (const abs of files) {
    const rel = path.relative(PLUGIN_ROOT, abs);

    // Skip non-text files
    if (!/\.(md|sh|json|ts|yaml|yml)$/.test(rel)) continue;
    // Skip plan files
    if (rel.startsWith('.claude/plans/')) continue;
    // Skip the lint script itself (it embeds the regexes literally)
    if (rel === 'scripts/lint_skill_content.ts') continue;

    const content = fs.readFileSync(abs, 'utf-8');
    const lines = content.split('\n');

    for (const rule of LEGACY_RULES) {
      if (isAllowed(rel, rule.allowIn)) continue;
      lines.forEach((line, idx) => {
        if (!rule.pattern.test(line)) return;
        // Meta-mentions that warn against the legacy pattern are allowed.
        // Heuristic: skip when the current line OR the closest preceding non-empty line
        // explicitly frames the pattern as deprecated/legacy/to-migrate.
        if (META_MENTION_REGEX.test(line)) return;
        // Walk up to 8 preceding non-empty lines — supports bullet lists under a "legacy / anti-regression / must be absent" header.
        let scanned = 0;
        for (let prev = idx - 1; prev >= 0 && scanned < 8; prev--) {
          if (lines[prev].trim() === '') continue;
          scanned++;
          if (META_MENTION_REGEX.test(lines[prev])) return;
        }
        findings.push({
          file: rel,
          line: idx + 1,
          ruleId: rule.id,
          message: rule.message,
          excerpt: line.trim().slice(0, 200),
        });
      });
    }
  }

  return findings;
}

// ============================================
// MAIN
// ============================================

console.log('===========================================');
console.log('Skill content lint (superpowers-api-platform)');
console.log('===========================================\n');

lintSkillStructure();

const findings = lintLegacyPatterns();

if (findings.length > 0) {
  console.error(`\nFound ${findings.length} legacy pattern occurrence(s):\n`);
  const byFile = new Map<string, Finding[]>();
  for (const f of findings) {
    if (!byFile.has(f.file)) byFile.set(f.file, []);
    byFile.get(f.file)!.push(f);
  }
  for (const [file, items] of byFile) {
    console.error(`  ${file}`);
    for (const f of items) {
      console.error(`    L${f.line} [${f.ruleId}] ${f.message}`);
      console.error(`      > ${f.excerpt}`);
    }
    console.error('');
  }
  console.error('Fix the occurrences above, or move legacy examples into skills/api-platform-upgrade/.\n');
  failed = true;
}

if (failed) {
  console.error('Skill content lint FAILED.');
  process.exit(1);
}

console.log('All checks passed.');
