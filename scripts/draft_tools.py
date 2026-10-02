import argparse
import copy
import json
import os
import pathlib
import sys


class ContractError(Exception):
    pass


def load(path):
    return json.loads(pathlib.Path(path).read_text())


def contract(root, graph_path):
    graph = load(graph_path)
    if graph.get("ok") is not True:
        raise ContractError("Local Railway graph evaluation failed")
    services = {
        item["name"]: item
        for item in graph["graph"]["resources"]
        if item["type"] == "service"
    }
    defaults = load(root / "template-defaults.json")
    descriptions = load(root / "template-descriptions.json")
    networking = load(root / "template-networking.json")
    volumes = load(root / "template-volumes.json")
    if set(services) != set(defaults) or set(defaults) != set(descriptions) or set(networking) != set(services):
        raise ContractError("Local service configuration sets differ")
    for name in defaults:
        if set(defaults[name]) != set(descriptions[name]):
            raise ContractError("Variable description set differs")
    graph_volumes = {
        item["address"]: item
        for item in graph["graph"]["resources"]
        if item["type"] == "volume"
    }
    attached_volumes = []
    for name, desired in services.items():
        actual_variables = desired.get("variables", {})
        if set(actual_variables) != set(defaults[name]):
            raise ContractError("Graph/default variable sets differ")
        for key, default in defaults[name].items():
            if actual_variables[key].get("value") != default:
                raise ContractError("Graph/default values differ; secret generators must stay as template placeholders")
        network = desired.get("networking") or {}
        domains = network.get("serviceDomains") or {}
        port = networking[name].get("publicPort")
        if network.get("tcpProxies") or network.get("customDomains"):
            raise ContractError("Graph exposes an unexpected public backend route")
        if port:
            if len(domains) != 1 or next(iter(domains.values())).get("port") != port:
                raise ContractError("Graph public port differs from metadata")
        elif domains:
            raise ContractError("Graph exposes a private backend")
        attachments = desired.get("volumeAttachments") or {}
        if name in volumes:
            if len(attachments) != 1:
                raise ContractError("Graph durable volume missing or duplicated")
            attachment = next(iter(attachments.values()))
            volume = graph_volumes.get(attachment["volume"], {})
            if attachment["mountPath"] != volumes[name]["mountPath"] or volume.get("config", {}).get("sizeMB") != volumes[name]["sizeMB"]:
                raise ContractError("Graph volume path/size differs from metadata")
            attached_volumes.append(attachment["volume"])
        elif attachments:
            raise ContractError("Graph stateless service has a volume")
    if len(attached_volumes) != len(set(attached_volumes)) or set(attached_volumes) != set(graph_volumes):
        raise ContractError("Graph has shared or orphan mutable volumes")
    return services, defaults, descriptions, networking, volumes


def unwrap(document):
    if "data" in document:
        return document["data"]["template"]["serializedConfig"]
    return document.get("serializedConfig", document)


def service_map(config):
    values = config.get("services", {})
    entries = values.values() if isinstance(values, dict) else values
    result = {}
    for value in entries:
        if value["name"] in result:
            raise ContractError("Duplicate draft service name")
        result[value["name"]] = value
    return result


def restore(document, expected):
    config = copy.deepcopy(unwrap(document))
    services, defaults, descriptions, networking, volumes = expected
    actual = service_map(config)
    if set(actual) != set(services):
        raise ContractError("Draft service set mismatch; create matching services before repair")
    for name, desired in services.items():
        service = actual[name]
        service["source"] = {key: value for key, value in desired["source"].items() if key != "type"}
        if desired["source"].get("repo"):
            service["build"] = copy.deepcopy(desired["build"])
        else:
            service.pop("build", None)
        service["deploy"] = copy.deepcopy(desired.get("deploy", {}))
        service["variables"] = {
            key: {"defaultValue": value, "description": descriptions[name][key], "isOptional": False}
            for key, value in defaults[name].items()
        }
        service["networking"] = {"serviceDomains": {}, "customDomains": {}, "tcpProxies": {}}
        port = networking[name].get("publicPort")
        if port:
            service["networking"]["serviceDomains"] = {"<hasDomain>": {"port": port}}
        mounts = service.get("volumeMounts", {}) or {}
        if name in volumes:
            if len(mounts) != 1:
                raise ContractError("Persistent services need exactly one existing draft volume; no IDs are fabricated")
            mount = next(iter(mounts.values()))
            mount["mountPath"] = volumes[name]["mountPath"]
            mount["sizeMB"] = volumes[name]["sizeMB"]
        else:
            service["volumeMounts"] = {}
    audit(config, expected)
    return config


def audit(document, expected):
    config = unwrap(document)
    services, defaults, descriptions, networking, volumes = expected
    actual = service_map(config)
    if set(actual) != set(services):
        raise ContractError("Draft service set mismatch")
    for name, desired in services.items():
        service = actual[name]
        if service.get("source") != {key: value for key, value in desired["source"].items() if key != "type"}:
            raise ContractError("Draft source differs from pinned local graph")
        if (service.get("build") or {}) != (desired.get("build") or {}):
            raise ContractError("Draft build/root configuration differs")
        if (service.get("deploy") or {}) != (desired.get("deploy") or {}):
            raise ContractError("Draft deployment commands/probes differ")
        variables = service.get("variables", {})
        if set(variables) != set(defaults[name]):
            raise ContractError("Draft variable name set differs")
        for key, default in defaults[name].items():
            variable = variables[key]
            if variable.get("defaultValue") != default or variable.get("description") != descriptions[name][key] or variable.get("isOptional") is not False:
                raise ContractError("Draft variable contract differs; values are deliberately not printed")
            if variable.get("value") or variable.get("encryptedValue"):
                raise ContractError("Resolved variable secret/value present in draft contract")
        network = service.get("networking", {}) or {}
        if network.get("tcpProxies") or network.get("customDomains"):
            raise ContractError("Unexpected public TCP proxy or custom domain")
        expected_port = networking[name].get("publicPort")
        domains = network.get("serviceDomains", {}) or {}
        if expected_port:
            if len(domains) != 1 or next(iter(domains.values())).get("port") != expected_port:
                raise ContractError("Public HTTP domain target mismatch")
        elif domains:
            raise ContractError("Private backend unexpectedly has a public domain")
        mounts = service.get("volumeMounts", {}) or {}
        if name in volumes:
            if len(mounts) != 1:
                raise ContractError("Exclusive durable volume is missing or duplicated")
            mount = next(iter(mounts.values()))
            if mount.get("mountPath") != volumes[name]["mountPath"] or mount.get("sizeMB") != volumes[name]["sizeMB"]:
                raise ContractError("Durable volume path/size differs")
        elif mounts:
            raise ContractError("Stateless service unexpectedly mounts a volume")
    volume_ids = [key for service in actual.values() for key in (service.get("volumeMounts") or {})]
    if len(volume_ids) != len(set(volume_ids)):
        raise ContractError("Shared cross-service mutable volume is forbidden")


def main():
    parser = argparse.ArgumentParser(description="Offline serialized draft repair/audit; no API calls")
    parser.add_argument("operation", choices=["restore", "audit"])
    parser.add_argument("input")
    parser.add_argument("graph")
    parser.add_argument("output", nargs="?")
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    try:
        expected = contract(root, args.graph)
        document = load(args.input)
        if args.operation == "restore":
            if not args.output:
                raise ContractError("Restore needs a local output path")
            output = pathlib.Path(args.output)
            if output.exists():
                raise ContractError("Refusing to overwrite an existing draft payload")
            payload = restore(document, expected)
            with open(output, "x", opener=lambda path, flags: os.open(path, flags, 0o600)) as stream:
                json.dump(payload, stream, indent=2)
                stream.write("\n")
            print("Prepared and audited local serializedConfig; no remote mutation performed")
        else:
            audit(document, expected)
            print("Offline source/command/variable/network/volume audit passed; no secret values printed")
    except (ContractError, KeyError, ValueError) as error:
        print("Draft contract rejected: " + (str(error) if isinstance(error, ContractError) else "Malformed input"), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
