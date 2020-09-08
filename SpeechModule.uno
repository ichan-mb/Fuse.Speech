using Uno;
using Uno.Collections;
using Fuse;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Scripting;
using Uno.UX;
using Uno.Threading;
using Uno.Permissions;

[Require("Xcode.Framework","AVFoundation.framework")]
[Require("Xcode.Framework","Speech.framework")]
[ForeignInclude(Language.ObjC, "Speech.hh")]
// Add app permissions
[Require("Xcode.Plist.Element", "<key>NSMicrophoneUsageDescription</key> <string>We are good listeners.</string>")]
[Require("Xcode.Plist.Element", "<key>NSSpeechRecognitionUsageDescription</key> <string>We would like to understand you.</string>")]

[ForeignInclude(Language.Java, "android.speech.tts.TextToSpeech", "android.speech.SpeechRecognizer", "android.speech.RecognizerIntent", "android.speech.RecognitionListener", "android.content.Intent", "android.os.Bundle", "java.util.Locale", "java.util.HashMap")]

[UXGlobalModule]
public class SpeechModule : NativeEventEmitterModule
{
	static readonly SpeechModule _instance;
	extern(iOS) ObjC.Object _speech;
	extern(Android) Java.Object _speech;
	extern(Android) Java.Object _tts;

	public SpeechModule(): base(true, "onResult", "onEnableChanged")
	{
		if(_instance != null) return;

		_instance = this;
		Resource.SetGlobalKey(_instance, "FuseJS/Speech");
		AddMember(new NativePromise<bool, bool>("requestPermission", RequestPermission, null));
		AddMember(new NativeFunction("startListening", (NativeCallback)Start));
		AddMember(new NativeFunction("stopListening", (NativeCallback)Stop));
		AddMember(new NativeFunction("startSpeaking", (NativeCallback)Speak));
		AddMember(new NativeFunction("stopSpeaking", (NativeCallback)StopSpeak));
		if defined(iOS)
			_speech = allocSpeech();
		if defined(Android)
		{
			_speech = allocSpeech(resultCb, statusCb);
			_tts = allocTTS();
		}
	}

	internal sealed class PermissionCallback
	{
		Promise<bool> _promise;
		Action<bool> _positive;

		public PermissionCallback(Promise<bool> promise)
		{
			_promise = promise;
		}

		public void Positive(bool value)
		{
			_promise.Resolve(value);
		}

		public extern(Android) PermissionCallback(Action<bool> positive)
		{
			_positive = positive;
		}

		public extern(Android) void OnPermitted(PlatformPermission permission)
		{
			_positive(true);
		}

		public extern(Android) void OnRejected(Exception e)
		{
			_positive(false);
		}
	}

	void resultCb( string str )
	{
		Emit("onResult", str);
	}
	void statusCb( bool isEnabled)
	{
		Emit("onEnableChanged", isEnabled);
	}

	public Future<bool> RequestPermission(object[] args)
	{
		var promise = new Promise<bool>();
		var cb = new PermissionCallback(promise);
		if defined(iOS)
			RequestPermissionIOS(_speech, cb.Positive);
		if defined(Android)
			RequestPermissionAndroid(cb.Positive);
		return promise;
	}

	object Start(Context c, object[] args)
	{
		if defined(iOS)
			startRecordingIOS(_speech, resultCb, statusCb );
		else if defined(Android)
			startRecordingAndroid(_speech, statusCb);
		else
			debug_log "Speech Recognition only implemented for Mobile";
		return null;
	}

	object Stop(Context c, object[] args)
	{
		if defined(iOS)
			stopRecordingIOS(_speech);
		else if defined(Android)
			stopRecordingAndroid(_speech);
		else
			debug_log "Speech Recognition only implemented for Mobile";
		return null;
	}

	object Speak(Context c, object[] args)
	{
		if (args.Length != 1)
			throw new Exception("speak() requires exactly 1 parameter.");
		var sentence = args[0] as string;
		if defined(iOS)
			speakIOS(_speech, sentence);
		else if defined(Android)
			speakAndroid(_tts, sentence);
		else
			debug_log "Text To Speach only implemented for mobile";
		return null;
	}

	object StopSpeak(Context c, object[] args)
	{
		if defined(iOS)
			stopSpeakIOS(_speech);
		else if defined(Android)
			stopSpeakAndroid(_tts);
		else
			debug_log "Text To Speach only implemented for mobile";
		return null;
	}

	// IOS Implementation
	[Foreign(Language.ObjC)]
	extern(iOS) ObjC.Object allocSpeech()
	@{
		return [[Speech alloc] init];
	@}

	[Foreign(Language.ObjC)]
	public extern(iOS) void startRecordingIOS(ObjC.Object speech, Action<string> rCb, Action<bool> sCb)
	@{
		[(Speech *)speech startRecording:rCb status:sCb];
	@}

	[Foreign(Language.ObjC)]
	public extern(iOS) void stopRecordingIOS(ObjC.Object speech)
	@{
		[(Speech *)speech stopRecording];
	@}

	[Foreign(Language.ObjC)]
	public extern(iOS) void speakIOS(ObjC.Object speech, string sentence)
	@{
		[(Speech *)speech startSpeaking:sentence];
	@}

	[Foreign(Language.ObjC)]
	public extern(iOS) void stopSpeakIOS(ObjC.Object speech)
	@{
		[(Speech *)speech stopSpeaking];
	@}

	[Foreign(Language.ObjC)]
	extern(iOS) void RequestPermissionIOS(ObjC.Object speech, Action<bool> resolve)
	@{
		[(Speech *)speech requestPermission:resolve];
	@}

	extern(Android) void RequestPermissionAndroid(Action<bool> resolve)
	{
		var permissionCallback = new PermissionCallback(resolve);
		Permissions.Request(Permissions.Android.RECORD_AUDIO).Then(permissionCallback.OnPermitted, permissionCallback.OnRejected);
	}

	[Foreign(Language.Java)]
	extern(Android) Java.Object allocSpeech(Action<string> rCb, Action<bool> sCb)
	@{
		SpeechRecognizer speechRecognizer = SpeechRecognizer.createSpeechRecognizer(com.fuse.Activity.getRootActivity());
		speechRecognizer.setRecognitionListener(new RecognitionListener() {
			@Override
			public void onReadyForSpeech(Bundle bundle) {
				if (sCb != null)
					sCb.run(true);

			}
			@Override
			public void onBeginningOfSpeech() {
				if (sCb != null)
					sCb.run(true);
			}
			@Override
			public void onRmsChanged(float v) {

			}
			@Override
			public void onBufferReceived(byte[] bytes) {

			}
			@Override
			public void onEndOfSpeech() {
				if (sCb != null)
					sCb.run(false);
			}
			@Override
			public void onError(int i) {
				if (sCb != null)
					sCb.run(false);

			}
			@Override
			public void onResults(Bundle bundle) {
				java.util.ArrayList<String> data = bundle.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
				if (rCb != null)
					rCb.run(data.get(0));
			}
			@Override
			public void onPartialResults(Bundle bundle) {
				java.util.ArrayList<String> data = bundle.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
				if (rCb != null)
					rCb.run(data.get(0));
			}
			@Override
			public void onEvent(int i, Bundle bundle) {

			}
		});
		return speechRecognizer;
	@}

	[Foreign(Language.Java)]
	extern(Android) Java.Object allocTTS()
	@{
		TextToSpeech tts = new TextToSpeech(com.fuse.Activity.getRootActivity(), new TextToSpeech.OnInitListener() {
			@Override
			public void onInit(int status) {
				if(status != TextToSpeech.ERROR) {

				}
			}
		});
		tts.setLanguage(new Locale("id", "ID"));
		return tts;
	@}

	[Foreign(Language.Java)]
	extern(Android) void startRecordingAndroid(Java.Object speech, Action<bool> sCb)
	@{
		com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() {
			@Override
			public void run() {
				final Intent speechRecognizerIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
				speechRecognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
				speechRecognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
				speechRecognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id_ID");

				((SpeechRecognizer)speech).startListening(speechRecognizerIntent);
				sCb.run(true);
			}
		});
	@}

	[Foreign(Language.Java)]
	extern(Android) void stopRecordingAndroid(Java.Object speech)
	@{
		com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() {
			@Override
			public void run() {
				((SpeechRecognizer)speech).stopListening();
			}
		});
	@}

	[Foreign(Language.Java)]
	public extern(Android) void speakAndroid(Java.Object speech, string sentence)
	@{
		com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() {
			@Override
			public void run() {
				HashMap<String, String> params = new HashMap<String, String>();
				params.put(TextToSpeech.Engine.KEY_PARAM_VOLUME, "1.0");
				((TextToSpeech)speech).speak(sentence, TextToSpeech.QUEUE_FLUSH, null);
			}
		});
	@}

	[Foreign(Language.Java)]
	public extern(Android) void stopSpeakAndroid(Java.Object speech)
	@{
		com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() {
			@Override
			public void run() {
				((TextToSpeech)speech).stop();
			}
		});
	@}
}