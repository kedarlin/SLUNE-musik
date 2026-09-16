package com.example.music.playback

import android.content.Context
import androidx.media3.common.Player
import androidx.media3.session.CommandButton
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import com.google.common.collect.ImmutableList

/**
 * Lets the user swap the notification's previous/next buttons for rewind/
 * fast-forward instead - post-processes the DEFAULT layout (rather than
 * building one from scratch) so play/pause, slots, and everything else
 * Media3 already gets right stay untouched; only the seek-to-track buttons
 * are swapped for seek-by-duration ones when [seekButtonsEnabled] is on.
 */
class NotificationButtonProvider(context: Context) : DefaultMediaNotificationProvider(context) {

    var seekButtonsEnabled: Boolean = false

    override fun getMediaButtons(
        session: MediaSession,
        playerCommands: Player.Commands,
        customLayout: ImmutableList<CommandButton>,
        showPauseButton: Boolean,
    ): ImmutableList<CommandButton> {
        val defaultButtons = super.getMediaButtons(session, playerCommands, customLayout, showPauseButton)
        if (!seekButtonsEnabled) {
            return defaultButtons
        }

        return ImmutableList.copyOf(
            defaultButtons.map { button ->
                when (button.playerCommand) {
                    Player.COMMAND_SEEK_TO_PREVIOUS, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM ->
                        CommandButton.Builder(CommandButton.ICON_REWIND)
                            .setPlayerCommand(Player.COMMAND_SEEK_BACK)
                            .setDisplayName("Rewind")
                            .setSlots(*button.slots.toArray())
                            .setEnabled(button.isEnabled)
                            .build()
                    Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM ->
                        CommandButton.Builder(CommandButton.ICON_FAST_FORWARD)
                            .setPlayerCommand(Player.COMMAND_SEEK_FORWARD)
                            .setDisplayName("Fast forward")
                            .setSlots(*button.slots.toArray())
                            .setEnabled(button.isEnabled)
                            .build()
                    else -> button
                }
            }
        )
    }
}
