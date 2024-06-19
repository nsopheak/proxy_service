import ballerina/http;
import ballerina/log;


final map<http:Client> clients = {};
final map<EndpointConfig> endpointConfigs = {};

function init() returns error? {
    foreach EndpointConfig endpoint in endpointConfig {
        http:Client|error 'client = new (endpoint.backendServiceEp);
        if 'client is error {
            log:printError("Error creating client for endpoint : " + endpoint.endpointContext, 'error = 'client);
            return error("Error creating client for endpoint : " + endpoint.endpointContext, 'error = 'client);
        }
        clients[endpoint.endpointContext] = 'client;
        endpointConfigs[endpoint.endpointContext] = endpoint;
    }
}


# A mediation service to perform mediation between the client and the backend service.
# bound to port `9090`.
service / on new http:Listener(8088) {

    resource function get [string ...paths](http:Caller caller, http:Request req) returns error? {
        log:printInfo("Received GET request for : " + req.rawPath);
        string contextPath = check resolveContextPath(req.rawPath);
        log:printInfo("Received GET request for contextPath : " + contextPath);
        http:Client 'client = check getClient(contextPath);
        string url = processRequestPath(req.rawPath);
        log:printInfo("Received GET request for URL : " + url);
        http:Response clientResponse = check 'client->execute(req.method, processRequestPath(req.rawPath), req);
        return replyToCaller(caller, clientResponse);
    }

    resource function post [string ...paths](http:Caller caller, http:Request req) returns error? {
        log:printInfo("Received POST request for : " + req.rawPath);
        string contextPath = check resolveContextPath(req.rawPath);
        http:Client 'client = check getClient(contextPath);
        http:Response clientResponse = check 'client->execute(req.method, processRequestPath(req.rawPath), req);
        return replyToCaller(caller, clientResponse);
    }
}


function getClient(string contextPath) returns http:Client|error {
    http:Client? 'client = clients[contextPath];
    if 'client == () {
        return error("Client not found for context path : " + contextPath);
    }
    return 'client;
}

function resolveContextPath(string path) returns string|error {
    foreach string contextPath in endpointConfigs.keys() {
        if path.startsWith(contextPath) {
            return contextPath;
        }
    }
    return error("No matching context path found for : " + path);
}

function getEndpointConfig(string contextPath) returns EndpointConfig|error {
    EndpointConfig? endpointConfig = endpointConfigs[contextPath];
    if endpointConfig == () {
        return error("Endpoint configuration not found for context path : " + contextPath);
    }
    return endpointConfig;
}

function replyToCaller(http:Caller caller, http:Response clientResponse) returns http:ListenerError? {
    check caller->respond(clientResponse);
}

function processRequestPath(string rawPath) returns string => re `^.*/`.replace(rawPath, "/");
