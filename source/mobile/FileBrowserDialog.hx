package mobile;

import openfl.Lib;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUI;
import haxe.io.Path;
import flixel.group.FlxSpriteGroup;
import lime.net.oauth.OAuthToken.RequestToken;
import openfl.sensors.Accelerometer;
import openfl.filesystem.FileStream;
import lime.app.Application;
import haxe.macro.Expr.Catch;
import sys.FileSystem;
import sys.io.File;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.FlxObject;
import flixel.group.FlxGroup;
import flixel.addons.ui.FlxInputText;
#if android
import lime.system.JNI;
// import android.widget.Toast;
#end

using StringTools;

enum FileBrowserType {
    SAVE_FILE;
    LOAD_FILE;
}

typedef Files = {
    file:String,
    text:FlxText,
    fullpath:String
}

typedef Dirs = {
    file:String,
    text:FlxText,
    fullpath:String
}

typedef QuickAccess = {
    name:String,
    path:String,
    text:FlxText
}

class FileBrowserDialog extends MusicBeatSubstate
{

    public var type:FileBrowserType = SAVE_FILE;
    public var data:String = "";
    public var defaultPath:String = "";
    public var defaultFileName:String = "file";
    public var curDirectory:String = "";
    public var extension:String = "json";
    public var touchPointScreen:FlxPoint;
    public var touchPoint:FlxPoint;
    private var camFollowPos:FlxObject;
    public var files:Array<Files> = [];
    public var dirs:Array<Dirs> = [];
    public var alls:Array<Dynamic> = [];
    public var icons:Array<FlxSprite> = [];
    public var paths:Array<FlxText> = [];
    public var pathTextToPath:Array<String> = [];
    public var quickAccess:Array<QuickAccess> = [];
    public var pathNext:Int = 0;
    public var lastFileList:Float = 0;

    public var cameraReset:Bool = true;

    private var onActionComplete:(path: String, name: String, cancelled:Bool) -> Void;

    public var error:FlxSprite;

    public var cancelButton:FlxSprite;
    public var actionButton:FlxSprite;

    public var textGroup:FlxGroup;

    public var iconGroup:FlxGroup;

    public var pathGroup:FlxSpriteGroup;

    public var pathTextGroup:FlxTypedSpriteGroup<FlxText>;

    public var fileInputText:FlxInputText;

    var blockPressWhileTypingOn:Array<FlxInputText> = [];

    public function new(type:FileBrowserType = SAVE_FILE, defaultPath:String = "", defaultFileName:String = "file", extension:String = "json", data:String = "you missed.", ?onComplete:(path: String, name: String, cancelled:Bool) -> Void = null, ?cameraReset = true) {
        this.defaultPath = defaultPath;
        this.defaultFileName = defaultFileName;
        this.extension = extension;
        this.type = type;
        this.data = data;
        this.onActionComplete = onComplete;
        this.cameraReset = cameraReset;

        super();
    }

    override function create() {

        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
        bg.screenCenter(XY);
        bg.scrollFactor.set();
        add(bg);

        textGroup = new FlxGroup();
        add(textGroup);

        iconGroup = new FlxGroup();
        add(iconGroup);

        var pathBody:FlxSprite = new FlxSprite(171, 40).loadGraphic(Paths.image("dialogs/FileDialog/pathBar"));
        pathBody.scrollFactor.set();
        add(pathBody);
        
        pathGroup = new FlxSpriteGroup();
        pathGroup.scrollFactor.set();
        add(pathGroup);

        pathTextGroup = new FlxTypedSpriteGroup<FlxText>();
        pathTextGroup.scrollFactor.set();
        add(pathTextGroup);

        var body:FlxSprite = new FlxSprite().loadGraphic(Paths.image("dialogs/FileDialog/dialogBody"));
        body.scrollFactor.set();
        add(body);

        var title:FlxText = new FlxText(0, 0, 0, "Save File", 24);
        switch (type)
        {
            case SAVE_FILE: title.text = "Save File";

            case LOAD_FILE: title.text = "Load File";
        }
        title.scrollFactor.set();
        title.antialiasing = ClientPrefs.globalAntialiasing;
        title.setFormat(Paths.font("notosans.otf"), 24, FlxColor.BLACK, LEFT, NONE);
        add(title);

        cancelButton = new FlxSprite(1000, 668).loadGraphic(Paths.image("dialogs/FileDialog/button"));
        cancelButton.scrollFactor.set();
        add(cancelButton);

        var cancelText:FlxText = new FlxText(cancelButton.x + 24, cancelButton.y, 0, "Cancel", 24);
        cancelText.scrollFactor.set();
        cancelText.setFormat(Paths.font("notosans.otf"), 24, FlxColor.BLACK, CENTER, NONE);
        cancelText.antialiasing = ClientPrefs.globalAntialiasing;
        add(cancelText);

        actionButton = new FlxSprite(1140, 668).loadGraphic(Paths.image("dialogs/FileDialog/button"));
        actionButton.scrollFactor.set();
        add(actionButton);

        var actionText:FlxText = new FlxText(actionButton.x + 36, actionButton.y, 0, "Save", 24);
        switch (type)
        {
            case SAVE_FILE: actionText.text = "Save";

            case LOAD_FILE: actionText.text = "Load";
        }
        actionText.scrollFactor.set();
        actionText.setFormat(Paths.font("notosans.otf"), 24, FlxColor.BLACK, CENTER, NONE);
        actionText.antialiasing = ClientPrefs.globalAntialiasing;
        add(actionText);

        fileInputText = new FlxInputText(350, 668, 600, defaultFileName, 24, FlxColor.BLACK, FlxColor.WHITE, true, true);
        fileInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
        fileInputText.antialiasing = ClientPrefs.globalAntialiasing;
        fileInputText.scrollFactor.set();
        add(fileInputText);
        blockPressWhileTypingOn.push(fileInputText);

        touchPointScreen = new FlxPoint();
        touchPoint = new FlxPoint();

        camFollowPos = new FlxObject(0, 350);

        FlxG.camera.follow(camFollowPos);

        if (FileSystem.exists(defaultPath))
        {
            reloadDirectory(defaultPath);
        }
        else close();

        createQuickAccess();

        super.create();
    }

    var previousTouchTick:Int;
    override function update(elapsed:Float) {

        for (touch in FlxG.touches.list)
        {
            if (touch.justPressed)
            {
                previousTouchTick = touch.justPressedTimeInTicks;
                touchPoint.x = camFollowPos.x;
                touchPoint.y = camFollowPos.y;
                touchPointScreen.x = touch.screenX;
                touchPointScreen.y = touch.screenY;
            }
            
            if (touch.justReleased)
            {
                if ((previousTouchTick - touch.justPressedTimeInTicks) < 5000)
                {
                    for (f in alls)
                        {
                            if (touch.overlaps(f.text))
                            {
                                if (FileSystem.exists(f.fullpath))
                                {
                                    if (FileSystem.isDirectory(f.fullpath))
                                        reloadDirectory(f.fullpath);
                                    else
                                        fileInputText.text = f.file;
                                    break;
                                }
                            }
                            else if (touch.overlaps(cancelButton))
                            {
                                if (cameraReset)
                                    FlxG.cameras.reset();
                                if (onActionComplete != null)
                                onActionComplete(null, null, true);
                                close();
                            }
                            else if (touch.overlaps(actionButton))
                            {
                                switch (type)
                                {
                                    case SAVE_FILE:
                                        var file:String = fileInputText.text;
                                        if (!file.endsWith("." + extension)) file = file + "." + extension;
                                        try {
                                            File.saveContent(curDirectory + "/" + file, data);
                                            // Toast.makeText("Saved!", Toast.LENGTH_SHORT);
                                            if (onActionComplete != null)
                                                onActionComplete(curDirectory + "/" + file, file, false);
                                            if (cameraReset)
                                                FlxG.cameras.reset();
                                            close();
                                        }
                                        catch (e)
                                        {
                                            // Toast.makeText("Could not save file. Try another directory.", Toast.LENGTH_LONG);
                                        }
                                    case LOAD_FILE:
                                        var file:String = fileInputText.text;
                                        if (FileSystem.exists(curDirectory + "/" + file))
                                        {
                                            if (onActionComplete != null)
                                            onActionComplete(curDirectory + "/" + file, file, false);
                                            if (cameraReset)
                                                FlxG.cameras.reset();
                                            close();
                                        }
                                        // else
                                            // Toast.makeText("File not found.", Toast.LENGTH_SHORT);
                                }
                            }
                        }
        
                        var pi:Int = 1;
                        for (p in paths)
                        {
                            if (touch.overlaps(p))
                            {
                                trace("overlap!" + pathTextToPath[pi]);
                                if (FileSystem.exists(pathTextToPath[pi]) && FileSystem.isDirectory((pathTextToPath[pi])))
                                    reloadDirectory(pathTextToPath[pi]);
                                break;
                            }
        
                            pi++;
                        }
        
                        for (ac in quickAccess)
                        {
                            if (touch.overlaps(ac.text))
                            {
                                if (FileSystem.exists(ac.path))
                                    reloadDirectory(ac.path);
                            }
                        }
                }
                
            }

            // camFollowPos.x = touchPoint.x + (touchPointScreen.x - touch.screenX);
            if (alls.length > 22)
            {
                camFollowPos.y = touchPoint.y + (touchPointScreen.y - touch.screenY);
                if (camFollowPos.y < 280) camFollowPos.y = 280;
                if (camFollowPos.y > lastFileList - 260) camFollowPos.y = lastFileList - 260;
            }
        }

        var blockInput:Bool = false;
        for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;

				if(FlxG.keys.justPressed.ENTER) inputText.hasFocus = false;
				break;
			}
		}

        if(!blockInput) {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			if(FlxG.keys.justPressed.ESCAPE) {
				MusicBeatState.switchState(new editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}
		}

        /*if (FlxG.keys.pressed.RIGHT) cancelButton.x += 1;

        if (FlxG.keys.pressed.LEFT) cancelButton.x -= 1;

        if (FlxG.keys.pressed.UP) cancelButton.y += 1;

        if (FlxG.keys.pressed.DOWN) cancelButton.y -= 1;

        trace(cancelButton.x + ", " + cancelButton.y);*/

        if (alls.length < 23)
            camFollowPos.y = 280;
        super.update(elapsed);
    }

    function reloadDirectory(directory:String = "") {

        if (error != null)
        {
            error.kill();
            remove(error);
            error.destroy();

            error = null;
        }

        for (f in alls)
        {
            f.text.kill();
            textGroup.remove(f.text);
            f.text.destroy();
        }

        for (i in icons)
        {
            i.kill();
            iconGroup.remove(i);
            i.destroy();
        }

        icons = [];

        files = [];
        dirs = [];
        alls = [];

            if (directory == null || directory == "") directory = curDirectory;

        try {
            for (item in FileSystem.readDirectory(directory))
            {
    
                if (!FileSystem.isDirectory(directory + "/" + item))
                {
                    if (item.endsWith("." + extension))
                    {
                        var ftext:FlxText = new FlxText(-450, 0, 0, item, 24);
                        ftext.setFormat(Paths.font("notosans.otf"), 24, FlxColor.BLACK, LEFT, NONE);
                        ftext.antialiasing = ClientPrefs.globalAntialiasing;
                        textGroup.add(ftext);
                        var f:Files = {file: "", text: null, fullpath: ""};
                        f.file = item;
                        f.text = ftext;
                        f.fullpath = directory + "/" + item;

                        files.push(f);
                    }
                }
                else 
                {
                    var ftext:FlxText = new FlxText(-450, 0, 0, item, 24);
                    ftext.setFormat(Paths.font("notosans.otf"), 24, FlxColor.BLACK, LEFT, NONE);
                    ftext.antialiasing = ClientPrefs.globalAntialiasing;
                    textGroup.add(ftext);

                    var d:Dirs = {file: "", text: null, fullpath: ""};
                    d.file = item;
                    d.text = ftext;
                    d.fullpath = directory + "/" + item;

                    dirs.push(d);

                }
    
            }
        }
        catch (e)
        {
            trace(e.stack);
            trace(e.message);
            trace(e.details());

            error = new FlxSprite(410, 115).loadGraphic(Paths.image("dialogs/FileDialog/error"));
            error.scrollFactor.set();
            error.antialiasing = ClientPrefs.globalAntialiasing;
            add(error);
        }

            sortFileList();

            curDirectory = directory;

            reloadPath();
            
            reloadText();
    }

    function reloadText() {

        pathNext = 0;
        
        for (i in 0...alls.length)
        {
            alls[i].text.y = i * 26 - 2;
            alls[i].text.updateHitbox();

            icons[i].y = i * 26;

            if (i == alls.length - 1) lastFileList = i * 26;
        }

        var allLength:Int = 0;

        for (p in paths)
        {
            allLength += p.text.length;
        }

        var val:Float = 170;
        for (i in 0...paths.length)
        {
            paths[i].x = val;
            val += paths[i].width + 16;
            var txt:FlxSprite = new FlxSprite(val - 20, paths[i].y + 5).loadGraphic(Paths.image("dialogs/FileDialog/next"));
            txt.antialiasing = ClientPrefs.globalAntialiasing;
            txt.scrollFactor.set();
            pathGroup.add(txt);
            pathNext++;

        }

        trace(allLength);
        trace(pathGroup.length);

        for (p in paths)
        {
            p.x += (80 - Math.max(allLength + pathNext, 80)) * 24; 
        }

        pathGroup.x = (80 - Math.max(allLength + pathNext, 80)) * 24;

    }

    function sortFileList() {
        files.sort(function(a:Files, b:Files):Int {
            return a.file > b.file ? 1 : -1;
        });

        dirs.sort(function(a:Files, b:Files):Int {
            return a.file > b.file ? 1 : -1;
        });

        alls = dirs.concat(files);

        for (f in alls)
        {
            if (FileSystem.isDirectory(f.fullpath))
            {
                var icon:FlxSprite = new FlxSprite(-480, 0).loadGraphic(Paths.image("dialogs/FileDialog/dir"));
                icon.antialiasing = ClientPrefs.globalAntialiasing;

                iconGroup.add(icon);

                icons.push(icon);
            }
            else 
            {
                var icon:FlxSprite = new FlxSprite(-480, 0).loadGraphic(Paths.image("dialogs/FileDialog/file"));
                icon.antialiasing = ClientPrefs.globalAntialiasing;

                iconGroup.add(icon);

                icons.push(icon);
            }
        }
    }

    function reloadPath() {

        pathGroup.forEach(function(spr) {
            spr.kill();
            pathGroup.remove(spr);
            spr.destroy();
        });

        pathTextGroup.forEach(function(spr) {
            spr.kill();
            pathTextGroup.remove(spr);
            spr.destroy();
        });

        paths = [];
        pathTextToPath = [];

        var indd:Int = 0;

        for (dr in curDirectory.split("/"))
        {
            if (dr == "" || dr == null) continue;

            var drt:FlxText = new FlxText(0, 37, 0, dr, 24);
            drt.scrollFactor.set();
            drt.ID = indd;
            drt.setFormat(Paths.font("notosans.otf"), 24, FlxColor.BLACK, LEFT, NONE);
            drt.antialiasing = ClientPrefs.globalAntialiasing;
            pathTextGroup.add(drt);
            paths.push(drt);

            indd++;
        }

        var ind:Int = 1;

        for (i in 0...paths.length)
        {
            if (curDirectory.split("/")[ind] == "" || curDirectory.split("/")[ind] == null) ind++;
            
            var path:String = "/";

            for (n in 0...ind)
            {
                //trace(curDirectory.split("/").length);
                if (curDirectory.split("/")[n] == "" || curDirectory.split("/")[n] == null) continue;

                path += curDirectory.split("/")[n] + "/";
            }

            path = path.substr(0, path.length - 1);

            //trace(path);
            //trace(i);
            
            if (paths[i] != null)
            {
                // trace(paths[i].text);
                pathTextToPath.insert(i, path);
            }
            ind++;
        }
    }

    function backDirectory() {
        if (curDirectory == "/") return;
        reloadDirectory((FileSystem.fullPath(curDirectory + "/..")));
    }

    var quickAccessList = [
        ["Home", "homeButton", "/storage/emulated/0"],
        ["App", "pe", SUtil.getPathNoSlash()],
        ["Root", "root", "/"],
        ["SD", "sd", "/sdcard"]
    ];
    function createQuickAccess() {
        var val:Float = 90;
        for (ac in quickAccessList)
        {
            
            trace("dialogs/FileDialog/" + ac[1]);
            var icon:FlxSprite = new FlxSprite(10, val + 5).loadGraphic(Paths.image("dialogs/FileDialog/" + ac[1]));
            icon.scrollFactor.set();
            add(icon);

            var label:FlxText = new FlxText(40, val, 0, ac[0], 24).setFormat(Paths.font("notosans.otf"), 24, FlxColor.WHITE, LEFT, NONE);
            label.scrollFactor.set();
            add(label);

            var qa:QuickAccess = { text: null, name: null, path: null};
            qa.name = ac[0];
            qa.text = label;
            qa.path = ac[2];

            val += 30;

            quickAccess.push(qa);
        }
    }
}