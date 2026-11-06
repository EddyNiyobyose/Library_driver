#!/bin/sh
# RTMO-s box test v3 (SPPF+Focus body, capped/uncapped tails, 2 load tests, on-box report), host-side steps on gateway 006 (run as root on ared-distro). Read-only test.
# Eddy places this file and box_package_rtmo_v3.zip in the host /tmp. Each step is one command:
#   sh /tmp/rtmo_box_steps_v3.sh check    container id + zip checksum (writes nothing)
#   sh /tmp/rtmo_box_steps_v3.sh place    copy the zip into the AI container /tmp and unpack it, verify checksums
#   sh /tmp/rtmo_box_steps_v3.sh start    start the test in the background (about 15 minutes; last 6.5 min = load tests)
#   sh /tmp/rtmo_box_steps_v3.sh status   progress; "ALL_DONE" at the end, then the report (paste it back; no file needs to leave the box)
#   sh /tmp/rtmo_box_steps_v3.sh pack     optional: write /tmp/rtmo_results_v3.tgz on the host for Eddy (prints its checksum)
#   sh /tmp/rtmo_box_steps_v3.sh clean    remove everything this test wrote (after you have pasted the report)
# Writes only: container /tmp/edgevision_rtmo_test3/, host /tmp/rtmo_results_v3.tgz. Nothing else is changed.
set -u
ZIP=/tmp/box_package_rtmo_v3.zip
EXPECT_SHA=${EXPECT_SHA:-}
T=/tmp/edgevision_rtmo_test3
PKG=$T/box_package_rtmo_v3
C=$(crictl ps --name edgevision-ai-toolkit2 -q 2>/dev/null | head -1)
[ -n "$C" ] || { echo "AI container edgevision-ai-toolkit2 not found"; exit 1; }
ex() { crictl exec "$C" sh -c "$1"; }

case ${1:-} in
  check)
    echo "AI container: $C"
    crictl ps --name edgevision-ai-toolkit2 2>/dev/null
    ls -la "$ZIP" && sha256sum "$ZIP"
    [ -z "$EXPECT_SHA" ] || { sha256sum "$ZIP" | grep -q "^$EXPECT_SHA " && echo ZIP_SHA_OK || echo ZIP_SHA_MISMATCH; }
    ex "df -h /tmp | tail -1; python3 -c 'import onnxruntime, rknnlite; print(\"onnxruntime\", onnxruntime.__version__, \"rknnlite OK\")'" ;;
  place)
    crictl exec -i "$C" sh -c "mkdir -p $T && cat > $T/pkg.zip" < "$ZIP"
    ex "cd $T && python3 -m zipfile -e pkg.zip . && rm pkg.zip && cd box_package_rtmo_v3 && ls && echo checksum_failures: \$(sha256sum -c SHA256SUMS | grep -vc ': OK\$')" ;;
  start)
    ex "cd $PKG && setsid nohup sh run_box_test.sh > run.out 2>&1 < /dev/null &"
    sleep 20
    ex "cat $PKG/results/STATUS" ;;
  status)
    ex "cat $PKG/results/STATUS; echo ---; cat $PKG/results/report.txt 2>/dev/null || echo 'not done yet'" ;;
  pack)
    ex "cd $PKG && tar czf - results" > /tmp/rtmo_results_v3.tgz && sha256sum /tmp/rtmo_results_v3.tgz && ls -la /tmp/rtmo_results_v3.tgz ;;
  clean)
    ex "rm -rf $T" && rm -f "$ZIP" /tmp/rtmo_results_v3.tgz /tmp/rtmo_box_steps_v3.sh && echo removed ;;
  *)
    sed -n '2,12p' "$0"; exit 2 ;;
esac
