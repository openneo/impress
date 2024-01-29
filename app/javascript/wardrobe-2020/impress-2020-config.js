const ORIGIN = readOrigin();
const SUPPORT_SECRET = readSupportSecret();

export function buildImpress2020Url(path) {
	return new URL(path, ORIGIN).toString();
}

export function getSupportSecret() {
	return SUPPORT_SECRET;
}

function readOrigin() {
	const node = document.querySelector("meta[name=impress-2020-origin]");
	return node?.content || "https://impress-2020.openneo.net"
}

function readSupportSecret() {
	const node = document.querySelector("meta[name=impress-2020-support-secret]");
	return node?.content || null;
}
