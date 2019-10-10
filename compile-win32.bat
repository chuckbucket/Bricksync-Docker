set PATH=C:\alexis\mingw32\mingw32\bin
gcc -std=gnu99 -m32 cpuconf.c cpuinfo.c -O2 -s -o cpuconf

cpuconf.exe -h

windres bricksync.rc -O coff -o bricksync.res
gcc -std=gnu99 -I./build-win32/ -L./build-win32/ -m32 bricksync.c bricksyncconf.c bricksyncnet.c bricksyncinit.c bricksyncinput.c bsantidebug.c bsmessage.c bsmathpuzzle.c bsorder.c bsregister.c bsapihistory.c bstranslation.c bsevalgrade.c bsoutputxml.c bsorderdir.c bspriceguide.c bsmastermode.c bscheck.c bssync.c bsapplydiff.c bsfetchorderinv.c bsresolve.c bscatedit.c bsfetchinv.c bsfetchorderlist.c bsfetchset.c bscheckreg.c bsfetchpriceguide.c tcp.c vtlex.c cpuinfo.c antidebug.c mm.c mmhash.c mmbitmap.c cc.c ccstr.c debugtrack.c tcphttp.c oauth.c bricklink.c brickowl.c brickowlinv.c colortable.c json.c bsx.c bsxpg.c journal.c exclperm.c iolog.c crypthash.c cryptsha1.c rand.c bn512.c bn1024.c rsabn.c bricksync.res -O2 -s -fvisibility=hidden -o bricksync -lm -lwsock32 -lws2_32 -lssleay32 -leay32
pause



