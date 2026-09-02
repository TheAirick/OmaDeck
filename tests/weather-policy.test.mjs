import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
import test from "node:test";

function loadPolicy() {
  const source = fs
    .readFileSync(new URL("../services/WeatherPolicy.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*/m, "");
  const context = {};
  vm.runInNewContext(source, context, { filename: "WeatherPolicy.js" });
  return context;
}

test("disabled weather never permits a refresh", () => {
  const policy = loadPolicy();

  assert.equal(policy.canRefresh(false, "/plugin"), false);
  assert.equal(policy.canRefresh(false, ""), false);
  assert.equal(policy.canRefresh(true, ""), false);
  assert.equal(policy.canRefresh(true, "/plugin"), true);
});

test("a disable transition invalidates an in-flight weather result", () => {
  const policy = loadPolicy();
  const beforeDisable = 7;
  const afterDisable = policy.nextGeneration(beforeDisable);

  assert.equal(policy.acceptsResult(false, beforeDisable, afterDisable), false);
  assert.equal(policy.acceptsResult(true, beforeDisable, afterDisable), false);
  assert.equal(policy.acceptsResult(true, afterDisable, afterDisable), true);
});

test("only enabled periodic triggers are allowed to refresh", () => {
  const policy = loadPolicy();

  for (const trigger of ["startup", "manual", "location", "retry", "periodic"]) {
    assert.equal(policy.canHandleTrigger(false, trigger, "/plugin"), false, trigger);
    assert.equal(policy.canHandleTrigger(true, trigger, "/plugin"), true, trigger);
  }
  assert.equal(policy.canHandleTrigger(true, "unknown", "/plugin"), false);
});

test("WeatherController routes every trigger through the enabled policy", () => {
  const controller = fs.readFileSync(
    new URL("../services/WeatherController.qml", import.meta.url),
    "utf8",
  );

  assert.match(controller, /import "WeatherPolicy\.js" as WeatherPolicy/);
  assert.match(controller, /property bool enabled: false/);
  for (const trigger of ["startup", "location", "retry", "periodic"]) {
    assert.match(controller, new RegExp(`refresh\\("${trigger}"\\)`), trigger);
  }
  assert.match(controller, /String\(trigger \|\| "manual"\)/);
  assert.match(controller, /WeatherPolicy\.acceptsResult\(/);
  assert.match(controller, /running: root\.enabled/);
  assert.match(controller, /weatherProcess\.signal\(9\)/);
  assert.match(controller, /property bool requestActive: false/);
  assert.match(controller, /if \(requestActive\)/);
  assert.match(controller, /requestActive = false/);
  assert.match(controller, /stdout:\s*BoundedOutputParser\s*\{[\s\S]*maxBytes:\s*16 \* 1024/);
  assert.match(controller, /command:\s*\[root\.pluginDir \+ "\/scripts\/weather-location"/);
  assert.doesNotMatch(controller, /\bStdioCollector\s*\{|\bFileView\s*\{/);
});

test("weather helpers bound remote bodies, lifecycle, output, and location input", () => {
  const helper = fs.readFileSync(
    new URL("../scripts/weather-json", import.meta.url),
    "utf8",
  );
  const location = fs.readFileSync(
    new URL("../scripts/weather_location.py", import.meta.url),
    "utf8",
  );

  assert.match(helper, /MAX_BODY_BYTES = 256 \* 1024/);
  assert.match(helper, /TOTAL_TIMEOUT_SECONDS = 10\.0/);
  assert.match(helper, /response\.read\(min\(16384, MAX_BODY_BYTES - len\(output\) \+ 1\)\)/);
  assert.match(helper, /MAX_OUTPUT_BYTES = 16 \* 1024/);
  assert.match(helper, /number\(latitude, -90, 90\)/);
  assert.match(helper, /number\(longitude, -180, 180\)/);
  assert.match(location, /os\.O_NOFOLLOW/);
  assert.match(location, /MAX_LOCATION_BYTES = 64 \* 1024/);
});
