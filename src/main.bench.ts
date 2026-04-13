import { bench, describe } from "vitest";
import { add } from "./main.js";

describe("add", () => {
  bench("add", () => {
    add(2, 3);
  });
});
