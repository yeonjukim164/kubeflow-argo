"""Git 에 선언한 실행을 KFP 에 제출한다. 같은 이름의 run 이 이미 있으면 아무것도 하지 않는다(다시 sync 해도 중복 실행 없음)."""
import json
import os
import sys

import kfp
import yaml

NS = os.environ["NAMESPACE"]
name, rev = os.environ["RUN_NAME"], os.environ.get("GIT_REVISION", "")
spec = yaml.safe_load(open("/spec/run.yaml"))
# 파드의 서비스 어카운트 토큰(대상 pipelines.kubeflow.org)으로 인증한다. 비밀번호를 쓰지 않는다.
c = kfp.Client(host="http://ml-pipeline.kubeflow.svc.cluster.local:8888", namespace=NS)
exp = c.create_experiment(spec["experiment"], namespace=NS)
flt = json.dumps({"predicates": [{"key": "display_name", "operation": "EQUALS", "string_value": name}]})
found = c.list_runs(experiment_id=exp.experiment_id, namespace=NS, filter=flt).runs
if found:
    print(f"already submitted: {name} run_id={found[0].run_id} state={found[0].state}")
    sys.exit(0)
r = c.create_run_from_pipeline_package(f"/pipelines/{spec['pipeline']}", arguments=spec.get("parameters") or {},
                                       run_name=name, experiment_name=spec["experiment"], namespace=NS,
                                       enable_caching=bool(spec.get("cache", False)))
print(f"submitted: {name} run_id={r.run_id} git={rev} parameters={spec.get('parameters')}")
