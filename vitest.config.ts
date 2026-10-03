import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
    clearMocks: true,
    restoreMocks: true,
    coverage: {
      provider: "v8",
      // json-summary は PR コメントの Markdown 表の生成に使う（.github/workflows/test.yml）
      reporter: ["text", "html", "lcov", "json-summary"],
      reportsDirectory: "./coverage",
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.test.ts", "src/**/*.bench.ts"],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80,
      },
    },
    benchmark: {
      include: ["src/**/*.bench.ts"],
    },
  },
});
