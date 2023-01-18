package;

#if (android && MODS_ALLOWED)
import android.AndroidTools;
import android.Permissions;
#end
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import openfl.utils.Assets as OpenFlAssets;
import openfl.Lib;
import haxe.CallStack.StackItem;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * ...
 * @author: Saw (M.A. Jigsaw)
 */

using StringTools;

class SUtil
{
	#if (android && MODS_ALLOWED)
	private static var aDir:String = null; // android dir
	private static var aDirn:String = null;
	#end

	public static function getPath():String
	{
		#if (android && MODS_ALLOWED)
		if (aDir != null && aDir.length > 0)
			return aDir;
		else
			return aDir = AndroidTools.getExternalStorageDirectory() + '/' + '.' + Application.current.meta.get('file') + '/';
		#else
		return '';
		#end
	}

	public static function getPathNoSlash():String
	{
		#if (android && MODS_ALLOWED)
		if (aDirn != null && aDirn.length > 0)
			return aDirn;
		else
			return aDirn = AndroidTools.getExternalStorageDirectory() + '/' + '.' + Application.current.meta.get('file');
		#else
		return '';
		#end
	}

	public static function doTheCheck()
	{
		#if (android && MODS_ALLOWED)
		if (!AndroidTools.getGrantedPermissions().contains(Permissions.READ_EXTERNAL_STORAGE) || !AndroidTools.getGrantedPermissions().contains(Permissions.WRITE_EXTERNAL_STORAGE))
		{
			AndroidTools.requestPermissions([Permissions.READ_EXTERNAL_STORAGE, Permissions.WRITE_EXTERNAL_STORAGE]);
			SUtil.applicationAlert('Permissions', "if you accepted the permissions all good if not expect a crash" + '\n' + 'Press Ok to see what happens');//shitty way to stop the app
		}

		if (AndroidTools.getGrantedPermissions().contains(Permissions.READ_EXTERNAL_STORAGE) || AndroidTools.getGrantedPermissions().contains(Permissions.WRITE_EXTERNAL_STORAGE))
		{
			if (!FileSystem.exists(AndroidTools.getExternalStorageDirectory() + '/' + '.' + Application.current.meta.get('file') + '/'))
				FileSystem.createDirectory(AndroidTools.getExternalStorageDirectory() + '/' + '.' + Application.current.meta.get('file') + '/');

			if (!FileSystem.exists(SUtil.getPath() + 'assets/') && !FileSystem.exists(SUtil.getPath() + 'mods/'))
			{
				SUtil.applicationAlert('Error!', "Whoops, seems you didn't extract the files from the .APK!\nPlease watch the tutorial by pressing OK.");
				openLinkAndClose();
			}
			else
			{
				if (!FileSystem.exists(SUtil.getPath() + 'assets/'))
				{
					SUtil.applicationAlert('Uncaught Error :(!', "Whoops, seems you didn't extract the assets/assets folder from the .APK!\nPlease watch the tutorial by pressing OK.");
					openLinkAndClose();
				}

				if (!FileSystem.exists(SUtil.getPath() + 'mods/'))
				{
					SUtil.applicationAlert('Uncaught Error :(!', "Whoops, seems you didn't extract the assets/mods folder from the .APK!\nPlease watch the tutorial by pressing OK.");
					openLinkAndClose();
				}
			}
		}
		#end
	}

	public static function gameCrashCheck()
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
	}

	static function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;

		path = SUtil.getPath() + "crash/" + "PsychEngine_" + dateNow + ".txt";

		trace(path);

		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);

		File.saveContent(path, errMsg + "\n");
		#end

		Sys.println(errMsg);

		Application.current.window.alert(errMsg, "Error!");
		Sys.exit(1);
	}

	private static function applicationAlert(title:String, description:String)
	{
		Application.current.window.alert(description, title);
	}

	private static function openLinkAndClose()
	{
		CoolUtil.browserLoad('https://youtu.be/zjvkTmdWvfU');
		Sys.exit(1);
	}

	#if android
	public static function saveContent(fileName:String = 'file', fileExtension:String = '.json', fileData:String = 'you forgot something to add in your code')
	{
		#if (android && MODS_ALLOWED)
                if (!FileSystem.exists(SUtil.getPath() + "saves")){
                        FileSystem.createDirectory(SUtil.getPath() + "saves");
                }

                File.saveContent(SUtil.getPath() + "saves/" + fileName + fileExtension, fileData);
                SUtil.applicationAlert("Done Action :)", "File Saved Successfully!");
                #elseif android
                openfl.system.System.setClipboard(fileData);
                SUtil.applicationAlert("Done Action :)", "Data Saved to Clipboard Successfully!");
                #end
	}

	public static function saveClipboard(fileData:String = 'you forgot something to add in your code')
	{
		openfl.system.System.setClipboard(fileData);
		SUtil.applicationAlert('Done!', 'Data Saved to Clipboard Successfully!');
	}

	public static function copyContent(copyPath:String, savePath:String)
	{
		if (!FileSystem.exists(savePath))
			File.saveBytes(savePath, OpenFlAssets.getBytes(copyPath));
	}
	#end
}