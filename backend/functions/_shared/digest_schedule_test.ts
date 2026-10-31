import { strict as assert } from "node:assert";
import { isDigestDue, isWeekend, localDateTime } from "./digest_schedule.ts";

Deno.test("digest is due in the five-minute scheduler window", () => {
  assert.equal(
    isDigestDue(
      new Date("2026-10-30T15:04:00Z"),
      "America/Los_Angeles",
      "08:00",
    ),
    true,
  );
  assert.equal(
    isDigestDue(
      new Date("2026-10-30T15:05:00Z"),
      "America/Los_Angeles",
      "08:00",
    ),
    false,
  );
});

Deno.test("digest time uses the configured local date across daylight time", () => {
  assert.equal(
    localDateTime(
      new Date("2026-10-30T15:00:00Z"),
      "America/Los_Angeles",
    ).date,
    "2026-10-30",
  );
  assert.equal(
    localDateTime(new Date("2026-11-02T16:00:00Z"), "America/Los_Angeles")
      .minuteOfDay,
    8 * 60,
  );
});

Deno.test("weekend check follows the configured time zone", () => {
  assert.equal(
    isWeekend(new Date("2026-10-31T12:00:00Z"), "America/Los_Angeles"),
    true,
  );
  assert.equal(
    isWeekend(new Date("2026-10-30T15:00:00Z"), "America/Los_Angeles"),
    false,
  );
});

Deno.test("invalid digest times fail explicitly", () => {
  assert.throws(() => isDigestDue(new Date(), "UTC", "25:00"));
});
