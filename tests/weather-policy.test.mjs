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
  assert.match(controller, /watchChanges: root\.enabled/);
  assert.match(controller, /weatherProcess\.signal\(9\)/);
  assert.match(controller, /!processExited \|\| !streamFinished/);
  assert.match(controller, /property bool requestActive: false/);
  assert.match(controller, /if \(requestActive\)/);
  assert.match(controller, /requestActive = false/);
  assert.match(controller, /onStreamFinished: \{[\s\S]*streamFinished = true/);
});

test("weather helper terminates its active curl child on SIGTERM", () => {
  const helper = fs.readFileSync(
    new URL("../scripts/weather-json", import.meta.url),
    "utf8",
  );

  assert.match(helper, /trap terminate_weather_request TERM INT/);
  assert.match(helper, /weather_curl_pid=/);
  assert.match(helper, /kill "\$weather_curl_pid"/);
  assert.match(helper, /fetch_json\(\) \{/);
});
