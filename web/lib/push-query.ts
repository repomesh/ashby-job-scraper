// Changes only the query string. Next syncs useSearchParams with history.pushState, so the feed
// refetches /api/jobs without a navigation: router.push would ask the server for the page again,
// which on the Cloudflare build is a static file that can't answer a Next page request and
// forces a full reload.
export const pushQuery = (query: string) => {
  window.history.pushState(null, "", query);
  // router.push scrolled to the top on a new page of results; pushState doesn't.
  window.scrollTo(0, 0);
};
