function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var allowedReferers = [${join(",", formatlist("\"%s\"", allowed_referers))}];

    var referer = headers.referer && headers.referer.value;

    if (!referer) {
        return {
            statusCode: 403,
            statusDescription: 'Forbidden',
            body: { encoding: 'text', data: 'Missing referer' }
        };
    }

    var isAllowed = allowedReferers.some(function (allowed) {
        return referer.indexOf(allowed) === 0;
    });

    if (!isAllowed) {
        return {
            statusCode: 403,
            statusDescription: 'Forbidden',
            body: { encoding: 'text', data: 'Referer not allowed' }
        };
    }

    return request;
}
