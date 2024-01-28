const IMPRESS_2020_ORIGIN = readImpress2020Origin();

export function buildImpress2020Url(path) {
	return new URL(path, IMPRESS_2020_ORIGIN).toString();
}

function readImpress2020Origin() {
	const node = document.querySelector("meta[name=impress-2020-origin]");
	return node?.content || "https://impress-2020.openneo.net"
}
