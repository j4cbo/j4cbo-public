/* Windex: Keep your window clean.
   Copyright (c) 2006 Jacob Potter

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
*/

(function() {
	var windowList = {
		"onload": true,
		"addEventListener": true,
		"location": true,
		"navigator": true,
		"headers": true
	};

	var dirtList, initDone;

	function doUpdate() {
		while (dirtList.firstChild) dirtList.removeChild(dirtList.firstChild);

		var dirtstr = [];
		for (var i in window) {
			if (windowList[i]) continue;

			if (i.slice(0, 2) == "[[") continue;
			var tli = document.createElement("LI");
			tli.appendChild(document.createTextNode(i));
			dirtList.appendChild(tli);
		}

		if (dirtList.childNodes.length > 0) {
			dirtList.style.display = "block";
		} else {
			dirtList.style.display = "none";
		}
	};

	function doInit(e) {
		dirtList = document.createElement("UL");
		dirtList.style.border = "1px solid red";
		dirtList.style.margin = "0";
		dirtList.style.padding = "5px";
		dirtList.style.color = "red";
		dirtList.style.background = "white";
		dirtList.style.position = "fixed";
		dirtList.style.top = "0px";
		dirtList.style.right = "0px";
		dirtList.style.display = "none";
		dirtList.style.listStylePosition = "inside";
		document.body.appendChild(dirtList);
	}

	function doRun() {
		if (!document.body) return;
		if (!initDone) doInit();
		doUpdate();
	}

	for (var i in window) windowList[i] = true;
	setInterval(doRun, 1000);
})();
