// ==UserScript==
// @name         Old Youtube Layout
// @namespace    http://greasyfork.ork/
// @version      0.1fix
// @description  youtube go back!
// @author       Tusk & Qfab
// @match        https://www.youtube.com/*
// @grant        none
// ==/UserScript==
'use strict';

function start() {
if(-1 === window.location.href.indexOf('?')){
	window.location.href = window.location.href + '?disable_polymer=true';
} else if(-1 === window.location.href.indexOf('disable_polymer=true')){
	window.location.href = window.location.href + '&disable_polymer=true';
}
}
start();
