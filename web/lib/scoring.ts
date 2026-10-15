import rules from "../../src/config/rules.json";

/** Tag options for the filter UI: every tag jobTags can give a job, sorted */
export const POSITIVE_TAG_OPTIONS: string[] = [
  ...new Set([
    ...Object.entries(rules.keywords)
      .filter(([, w]) => w > 0)
      .map(([k]) => k),
    ...Object.keys(rules.niches),
    ...rules.tags,
  ]),
].sort();
