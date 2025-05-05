mergeInto(LibraryManager.library, {
  Hello: function () {
  	alert("Hello, world!")
  },
  AddNumbers: function (x, y) {
    return x + y;
  },
  Echo: function (str) {
    var jsstr = UTF8ToString(str)
    var bufferSize = lengthBytesUTF8(jsstr) + 1;
    return stringToUTF8(jsstr, _malloc(bufferSize), bufferSize);
  },
  PrintArray: function (array, size) {
    for(var i = 0; i < size; i++)
        console.log(HEAPF32[(array >> 2) + i]);
  },
});