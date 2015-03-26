function getUUID() {
    var parts = document.URL.split('/');
    return parts[parts.length - 2];
}
