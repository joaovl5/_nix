/*
 * Maintain the session authenticated
 * */

function handleWheel(action, subject) {
	if (subject.isInGroup("wheel")) {
		return polkit.Result.YES;
	}
}

polkit.addRule(handleWheel);
