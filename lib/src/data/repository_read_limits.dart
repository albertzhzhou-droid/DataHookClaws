/// Normalizes a caller-provided repository page size without changing the
/// existing meaning of zero (an explicit empty page).
int normalizeRepositoryReadLimit(int limit) => limit < 0 ? 0 : limit;
