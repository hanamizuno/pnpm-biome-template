export function add(a: number, b: number): number {
  return a + b;
}

/* v8 ignore start: スクリプトとして直接実行された時のエントリ */
if (import.meta.main) {
  console.log("Add 2 + 3 =", add(2, 3));
}
/* v8 ignore stop */
