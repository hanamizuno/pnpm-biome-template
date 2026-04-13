export function add(a: number, b: number): number {
  return a + b;
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/.*\//, ""))) {
  console.log("Add 2 + 3 =", add(2, 3));
}
