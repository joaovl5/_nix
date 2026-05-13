/*
 * Maintain the session authenticated
 * */
polkit.addRule((action, subject) => {
	if (subject.isInGroup("wheel")) {
		return polkit.Result.YES;
	}
});
