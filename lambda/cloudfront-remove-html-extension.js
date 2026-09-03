'use strict';

const pointsToFile = uri => /\/[^/]+\.[^/]+$/.test(uri);
const hasTrailingSlash = uri => uri.endsWith('/');

exports.handler = (event, context, callback) => {
    // Extract the request from the CloudFront event that is sent to Lambda@Edge 
    var request = event.Records[0].cf.request;

    // Extract the URI and query string from the request
    const olduri = request.uri;
    const qs = request.querystring;

    if (pointsToFile(olduri)) {
        callback(null, request);
        return;
    }

    // Append ".html" extension
    if (!hasTrailingSlash(olduri)) {
        request.uri = olduri + ".html";
    } else {
    // Append "index.html"
        request.uri = olduri + "index.html";
    }

    // Return to CloudFront
    return callback(null, request);
};
