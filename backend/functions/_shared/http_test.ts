import { strict as assert } from "node:assert";
import { handlePostRequest } from "./http.ts";

Deno.test("OPTIONS preflight is answered without running the worker", async () => {
  const response = handlePostRequest(
    new Request("https://example.test", {
      method: "OPTIONS",
      headers: {
        Origin: "http://localhost:5173",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "authorization, apikey, content-type",
      },
    }),
  );
  assert.ok(response);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
  assert.equal(
    response.headers.get("Access-Control-Allow-Methods"),
    "POST, OPTIONS",
  );
  assert.equal(await response.text(), "ok");
});

Deno.test("worker rejects methods other than POST and OPTIONS", async () => {
  const response = handlePostRequest(
    new Request("https://example.test", { method: "GET" }),
  );
  assert.ok(response);
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
  assert.deepEqual(await response.json(), { error: "Method not allowed" });
});

Deno.test("POST proceeds to the worker", () => {
  assert.equal(
    handlePostRequest(new Request("https://example.test", { method: "POST" })),
    null,
  );
});
