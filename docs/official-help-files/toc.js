function clickHandler() {
  var targetId, srcElement, targetElement;
  srcElement = window.event.srcElement;
  if (srcElement.className == "node") {
     targetId = srcElement.id + "d";
     targetElement = document.all(targetId);
     if (targetElement.style.display == "none") {
        targetElement.style.display = "";
        srcElement.src = "images/minus.gif";
     } else {
        targetElement.style.display = "none";
        srcElement.src = "images/plus.gif";
     }
  }
}

document.onclick = clickHandler;

