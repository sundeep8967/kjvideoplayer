// File removed: NextPlayerLauncher.java is no longer needed. All video playback is handled by Flutter.

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;

public class NextPlayerLauncher {
    public static void launchNextPlayer(FlutterActivity activity, String videoPath) {
        // TODO: Replace this with the correct intent to launch NextPlayer's player activity
        Intent intent = new Intent();
        intent.setAction(Intent.ACTION_VIEW);
        intent.setDataAndType(Uri.fromFile(new File(videoPath)), "video/*");
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        // If NextPlayer has a custom Activity, use setClassName here
        // intent.setClassName("dev.anilbeesetti.nextplayer", "dev.anilbeesetti.nextplayer.PlayerActivity");
        activity.startActivity(intent);
    }
}
