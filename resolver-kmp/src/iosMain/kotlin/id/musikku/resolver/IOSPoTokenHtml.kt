package id.musikku.resolver

/**
 * BotGuard client executed only inside an isolated, non-persistent WKWebView.
 * The native host performs all network requests and never passes account cookies.
 */
internal val IOS_PO_TOKEN_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MusikKu Attestation Runtime</title>
<script>
(function () {
  "use strict";
  var bgVmFunctions = null;
  var bgVm = null;
  var bgProgram = null;
  var poTokenMinter = null;

  function loadBotGuard(challengeData) {
    bgVm = window[challengeData.globalName];
    bgProgram = challengeData.program;
    bgVmFunctions = null;
    if (!bgVm || typeof bgVm.a !== "function") {
      throw new Error("BotGuard interpreter is unavailable");
    }

    var callback = function (asyncSnapshotFunction, shutdownFunction, passEventFunction, checkCameraFunction) {
      bgVmFunctions = {
        asyncSnapshotFunction: asyncSnapshotFunction,
        shutdownFunction: shutdownFunction,
        passEventFunction: passEventFunction,
        checkCameraFunction: checkCameraFunction
      };
    };

    bgVm.a(bgProgram, callback, true, undefined, function () {}, [[], []]);

    return new Promise(function (resolve, reject) {
      var attempts = 0;
      var timer = setInterval(function () {
        if (bgVmFunctions && typeof bgVmFunctions.asyncSnapshotFunction === "function") {
          clearInterval(timer);
          resolve({ vmFunctions: bgVmFunctions, vm: bgVm, program: bgProgram });
        } else if (++attempts >= 10000) {
          clearInterval(timer);
          reject(new Error("Timed out waiting for BotGuard runtime"));
        }
      }, 1);
    });
  }

  function snapshot(botguard, webPoSignalOutput) {
    return new Promise(function (resolve, reject) {
      if (!botguard.vmFunctions || typeof botguard.vmFunctions.asyncSnapshotFunction !== "function") {
        reject(new Error("BotGuard snapshot function is unavailable"));
        return;
      }
      try {
        botguard.vmFunctions.asyncSnapshotFunction(function (response) {
          resolve(response);
        }, [undefined, undefined, webPoSignalOutput, undefined]);
      } catch (error) {
        reject(new Error("BotGuard snapshot failed: " + String(error)));
      }
    });
  }

  window.runBotGuard = function (challengeData) {
    var interpreter = challengeData &&
      challengeData.interpreterJavascript &&
      challengeData.interpreterJavascript.privateDoNotAccessOrElseSafeScriptWrappedValue;
    if (typeof interpreter !== "string" || !interpreter.length) {
      return Promise.reject(new Error("BotGuard interpreter JavaScript is missing"));
    }
    try {
      (new Function(interpreter))();
    } catch (error) {
      return Promise.reject(new Error("Could not initialize BotGuard interpreter: " + String(error)));
    }

    var webPoSignalOutput = [];
    return loadBotGuard({
      globalName: challengeData.globalName,
      program: challengeData.program
    }).then(function (botguard) {
      return snapshot(botguard, webPoSignalOutput);
    }).then(function (botguardResponse) {
      return {
        webPoSignalOutput: webPoSignalOutput,
        botguardResponse: botguardResponse
      };
    });
  };

  window.createPoTokenMinter = async function (webPoSignalOutput, integrityToken) {
    if (!webPoSignalOutput || typeof webPoSignalOutput[0] !== "function") {
      throw new Error("BotGuard minter factory is unavailable");
    }
    var result = webPoSignalOutput[0](integrityToken);
    var mintCallback = result && typeof result.then === "function" ? await result : result;
    if (typeof mintCallback !== "function") {
      throw new Error("BotGuard minter callback is invalid");
    }
    poTokenMinter = mintCallback;
  };

  window.obtainPoToken = async function (identifier) {
    if (typeof poTokenMinter !== "function") {
      throw new Error("BotGuard minter has not been initialized");
    }
    var result = poTokenMinter(identifier);
    result = result && typeof result.then === "function" ? await result : result;
    if (!(result instanceof Uint8Array)) {
      throw new Error("BotGuard returned an invalid token");
    }
    if (result.length < 1 || result.length > 4096) {
      throw new Error("BotGuard token size is invalid");
    }
    return result;
  };
})();
</script>
</head>
<body></body>
</html>
"""
