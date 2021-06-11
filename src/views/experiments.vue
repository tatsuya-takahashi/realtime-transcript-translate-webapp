<template src="./experiments.html"></template>
<style src="./experiments.scss" scoped lang="scss"></style>
<script>
// tsだと、getUserMediaがコンパイルエラーになるので、jsにする
import * as speechSdk from "microsoft-cognitiveservices-speech-sdk";
// const speechSKey = "5a6a3d13e6a34959bc9e7122a20f52bb"; // asahikasei
const speechSKey = "55bb3e290b3d4405abdc1e3cae706eab"; // DX1AG
const speechConfig = speechSdk.SpeechConfig.fromSubscription(speechSKey, "japaneast");
speechConfig.speechRecognitionLanguage = "ja-jp";
// speechConfig.speechRecognitionLanguage = "en-us";

// 翻訳用config
import axios from 'axios';
import {v4 as uuidv4} from 'uuid';
// const transSKey = "eb87360816204677a17423ccef781f8c"; // asahikasei
const transSKey = "d145a64af1614123a0cadb03589d4766"; // DX1AG
const endpoint = "https://api.cognitive.microsofttranslator.com/";
const location = "japaneast";
let localSourceNode
let recieveSourceNode
let localRecognizer
let recieveRecognizer

// 音声をwavで録音
let recordingData = [];
let recordingStartTime
let recordingsource
let recordingDataRecieve = [];
let recordingStartTimeRecieve
let recordingsourceRecieve
// bufferSizeを大きくするほどぶつ切り感が出ない
const bufferSize = 4096;
const sampleRate = 16000;

// 数字の0埋め(2桁)
function padding0(num){
  if(num > 10**1){
    return String(num)
  }else{
    return ( '00' + num ).slice( -2 )
  }
}

export default {
  name: 'Experiments',
  components: {
  },
  props: [],
  data:() => ({
    tableFields:[
      {key: 'localflg',label: 'デバイス',
        thStyle:"width: 10%;",
        formatter: value => {
          return value? "マイク":"スピーカー"
        }
      },
      {key: 'stTime',label: '時間',
        thStyle:"width: 10%;",
        formatter: value => {
          return padding0(value.getHours()) + ":" + padding0(value.getMinutes()) + ":" + padding0(value.getSeconds())
        }
      },
      {key: 'jaText',label: '本文',
        thStyle:"width: 50%;"
      },
      {key: 'enText',label: '翻訳',
        thStyle:"width: 30%;"
      }
    ],
    audioItems:[],
    localAudioWriting:false,
    recieveAudioWriting:false,
    vcmdMode:false
  }),
  computed: {
    startTime: function(){
      let stTime = new Date()
      if(this.audioItems.length > 0){
        stTime = this.audioItems[0].stTime
      }
      return stTime.getFullYear() + "/" + padding0(stTime.getMonth()+1) +"/" + padding0(stTime.getDate())
    },
    elapsedTime: function(){
      let ela = "00:00:00"
      if(this.audioItems.length > 0){
        const stTime = this.audioItems[0].stTime
        const now = new Date()
        const diff = now.getTime() - stTime.getTime()
        const hour =  Math.floor(diff/(60*60*1000))
        const min = Math.floor(diff/(60*1000) - hour*60)
        const sec = Math.floor(diff/1000 - hour*60*60 - min*60)
        ela = padding0(hour) + ":" + padding0(min) + ":" + padding0(sec)
      }
      return ela
    }
  },
  mounted () {
    // getLocalDevices()
    this.connectLocalAudio()
    this.connectRecieveAudio()
    const _this = this

    window.addEventListener('keydown', function(e) {
      // escキー
      if (!e.repeat && e.key === "Insert") {
        _this.vcmdMode = true
      }
    });
    window.addEventListener('keyup', function(e) {
      // escキー
      if (e.key === "Insert") {
        _this.vcmdMode = false
      }
    });
  },
  destroyed (){
    this.disconectDevice()
  },
  methods: {
    resetData(){
      this.audioItems = []
      this.localAudioWriting = false
      this.recieveAudioWriting = false
      this.vcmdMode = false
    },
    disconectDevice(){
      if(localSourceNode){
        localSourceNode.disconnect()
      }
      if(recieveSourceNode){
        recieveSourceNode.disconnect()
      }
      if(localRecognizer){
        localRecognizer.stopContinuousRecognitionAsync()
      }
      if(recieveRecognizer){
        recieveRecognizer.stopContinuousRecognitionAsync()
      }
      if(recordingsource){
        recordingsource.disconnect()
      }
      if(recordingsourceRecieve){
        recordingsourceRecieve.disconnect()
      }
    },
    // 値書き換え
    writeText(text,localflg){
      if(localflg){
        if(!this.localAudioWriting){
          // 確定直後なので新しく
          this.audioItems.push({jaText:text,enText:"",localflg:localflg,stTime:new Date(),finTime:null})
          this.localAudioWriting = true
        }else{
          // 更新中なので最新を
          const idx = this.audioItems.map(el=>el.localflg).lastIndexOf(localflg)
          this.audioItems[idx].jaText = text
        }
      }else{
        if(!this.recieveAudioWriting){
          // 確定直後なので新しく
          this.audioItems.push({jaText:text,enText:"",localflg:localflg,stTime:new Date(),finTime:null})
          this.recieveAudioWriting = true
        }else{
          // 更新中なので最新を
          const idx = this.audioItems.map(el=>el.localflg).lastIndexOf(localflg)
          this.audioItems[idx].jaText = text
        }
      }
    },
    confirmText(text,localflg){
      const idx = this.audioItems.map(el=>el.localflg).lastIndexOf(localflg)
      this.audioItems[idx].jaText = text
      this.audioItems[idx].finTime = new Date()
      this.translator(text,idx)
      if(localflg){
        this.localAudioWriting = false
      }else{
        this.recieveAudioWriting = false
      }
      this.scroll()
    },
    // 動作
    // メイン動作
    // マイクの音声を拾う
    connectLocalAudio () {
      const _this = this
      // const canvas = document.getElementById("localCanvas")
      const constraints = {
        audio: true,
        video: false
      }
      navigator.mediaDevices.getUserMedia(constraints)
        .then(stream => {
          // 波形描画
          // _this.drawWave(stream.clone(),canvas,true)
          // 音声録音
          // _this.startRecording(stream.clone())
          // 音声認識
          const audioConfig = speechSdk.AudioConfig.fromStreamInput(stream);
          // 音をそのままテキスト化
          localRecognizer = new speechSdk.SpeechRecognizer(speechConfig, audioConfig);
          _this.setRecognizerOption(localRecognizer,true);
          localRecognizer.startContinuousRecognitionAsync();
          
        }).catch(error => {
          console.error('mediaDevice.getUserMedia() error:', error)
        })
    },

    // PC上の音声を拾う
    connectRecieveAudio () {
      const _this = this
      // const canvas = document.getElementById("recieveCanvas")
      const constraints = {
        audio: true,
        video: true
      }
      navigator.mediaDevices.getDisplayMedia(constraints)
        .then(stream => {
          // _this.drawWave(stream.clone(),canvas,false)
          // 音声録音
          // _this.startRecordingRecieve(stream.clone())
          const audioConfig = speechSdk.AudioConfig.fromStreamInput(stream);
          recieveRecognizer = new speechSdk.SpeechRecognizer(speechConfig, audioConfig);
          _this.setRecognizerOption(recieveRecognizer,false);
          recieveRecognizer.startContinuousRecognitionAsync();
        }).catch(error => {
          console.error('mediaDevice.getUserMedia() error:', error)
          alert('音声共有を許可した上で、全画面共有してください')
          _this.connectRecieveAudio()
        })
    },

    // 翻訳
    translator(text,idx){
      const _this = this
      axios({
          baseURL: endpoint,
          url: '/translate',
          method: 'post',
          headers: {
              'Ocp-Apim-Subscription-Key': transSKey,
              'Ocp-Apim-Subscription-Region': location,
              'Content-type': 'application/json',
              'X-ClientTraceId': uuidv4().toString()
          },
          params: {
              'api-version': '3.0',
              'from': 'ja',
              'to': 'en'
              // 'from': 'en',
              //  'to': 'ja'
          },
          data: [{
              'text': text
          }],
          responseType: 'json'
      }).then(function(response){
          const result = response.data[0].translations[0].text
          if(_this.audioItems[idx]){
            _this.audioItems[idx].enText = result
          }
      })
    },
    // 録音開始
    startRecording(stream){
      recordingData = []
      const audioContext = new AudioContext({sampleRate:sampleRate});
      const scriptProcessor = audioContext.createScriptProcessor(bufferSize, 1, 1);
      recordingsource = audioContext.createMediaStreamSource(stream);
      recordingsource.connect(scriptProcessor);
      scriptProcessor.onaudioprocess = function(e) {
        if(recordingData.length == 0){
          recordingStartTime = new Date()
        }
        const input = e.inputBuffer.getChannelData(0);
        const bufferData = new Float32Array(bufferSize);
        for (let i = 0; i < bufferSize; i++) {
          bufferData[i] = input[i];
        }
        recordingData.push(bufferData);
      };
      scriptProcessor.connect(audioContext.destination);
    },
    // 録音開始
    startRecordingRecieve(stream){
      recordingDataRecieve = []
      const audioContext = new AudioContext({sampleRate:sampleRate});
      const scriptProcessor = audioContext.createScriptProcessor(bufferSize, 1, 1);
      recordingsourceRecieve = audioContext.createMediaStreamSource(stream);
      recordingsourceRecieve.connect(scriptProcessor);
      scriptProcessor.onaudioprocess = function(e) {
        if(recordingData.length == 0){
          recordingStartTimeRecieve = new Date()
        }
        const input = e.inputBuffer.getChannelData(0);
        const bufferData = new Float32Array(bufferSize);
        for (let i = 0; i < bufferSize; i++) {
          bufferData[i] = input[i];
        }
        recordingDataRecieve.push(bufferData);
      };
      scriptProcessor.connect(audioContext.destination);
    },
    // 録音ダウンロード(発信側)
    downloadRecording(){
      const downloadLink = document.getElementById('download')
      const audioBlob = this.createWAV(recordingData)
      const myURL = window.URL || window.webkitURL;
      downloadLink.href = myURL.createObjectURL(audioBlob);
      downloadLink.download = 'localAuio.wav';
      downloadLink.click();
    },
    createWAV(audioData,stSecond,finSecond) {
      const samples = this.cutSamples(this.mergeBuffers(audioData),stSecond,finSecond)
      const dataview = this.encodeWAV(samples, sampleRate);
      const audioBlob = new Blob([dataview], { type: 'audio/wav' });
      return audioBlob
    },
    // 音声のstreamを可視化する。音を拾えているかの確認用
    drawWave(stream,canvas,localflg) {
      const drawContext = canvas.getContext('2d');
      const audioContext = new AudioContext();
      const analyserNode = audioContext.createAnalyser();
      analyserNode.fftSize = 2048;
      if(localflg){
        localSourceNode = audioContext.createMediaStreamSource(stream);
        localSourceNode.connect(analyserNode);
      }else{
        recieveSourceNode = audioContext.createMediaStreamSource(stream);
        recieveSourceNode.connect(analyserNode);
      }

      function draw() {
        if(!drawContext) return
        const barWidth = canvas.width / analyserNode.fftSize;
        const array = new Uint8Array(analyserNode.fftSize);
        analyserNode.getByteTimeDomainData(array);
        drawContext.fillStyle = 'rgba(0, 0, 0, 1)';
        drawContext.fillRect(0, 0, canvas.width, canvas.height);

        for (let i = 0; i < analyserNode.fftSize; ++i) {
          const value = array[i];
          const percent = value / 255;
          const height = canvas.height * percent;
          const offset = canvas.height - height;

          drawContext.fillStyle = 'lime';
          drawContext.fillRect(i * barWidth, offset, barWidth, 2);
        }

        requestAnimationFrame(draw);
      }
      draw();
    },

    // サポート動作
    // 音声認識の挙動の規定
    setRecognizerOption(recognizer,localflg){
      const _this = this
      recognizer.recognizing = (s, e) => {
        // console.log(`RECOGNIZING: Text=${e.result.text}`);
        _this.writeText(e.result.text,localflg);
      };
      recognizer.recognized = (s, e) => {
        if (e.result.reason == speechSdk.ResultReason.RecognizedSpeech) {
            // console.log(`RECOGNIZED: Text=${e.result.text}`);
            _this.confirmText(e.result.text,localflg)

            if (_this.vcmdMode) {
              console.log("コマンド:"+e.result.text)
              if(e.result.text.indexOf("開発") > -1){
                window.location.href = '/dev';
              }
            }
        }
        else if (e.result.reason == speechSdk.ResultReason.NoMatch) {
            console.log("NOMATCH: Speech could not be recognized.");
        }
      };
      recognizer.canceled = (s, e) => {
        console.log(`CANCELED: Reason=${e.reason}`);
        // if (e.reason == CancellationReason.Error) {
        //     console.log(`"CANCELED: ErrorCode=${e.errorCode}`);
        //     console.log(`"CANCELED: ErrorDetails=${e.errorDetails}`);
        //     console.log("CANCELED: Did you update the subscription info?");
        // }
        recognizer.stopContinuousRecognitionAsync();
      };
      recognizer.sessionStopped = (s, e) => {
        console.log("\n    Session stopped event.");
        recognizer.stopContinuousRecognitionAsync();
      };
    },
    // wavファイルに変換
    encodeWAV(samples, sampleRate) {
      const buffer = new ArrayBuffer(44 + samples.length * 2);
      const view = new DataView(buffer);

      const writeString = function(view, offset, string) {
        for (let i = 0; i < string.length; i++){
          view.setUint8(offset + i, string.charCodeAt(i));
        }
      };

      const floatTo16BitPCM = function(output, offset, input) {
        for (let i = 0; i < input.length; i++, offset += 2){
          const s = Math.max(-1, Math.min(1, input[i]));
          output.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
        }
      };

      writeString(view, 0, 'RIFF');  // RIFFヘッダ
      view.setUint32(4, 32 + samples.length * 2, true); // これ以降のファイルサイズ
      writeString(view, 8, 'WAVE'); // WAVEヘッダ
      writeString(view, 12, 'fmt '); // fmtチャンク
      view.setUint32(16, 16, true); // fmtチャンクのバイト数
      view.setUint16(20, 1, true); // フォーマットID
      view.setUint16(22, 1, true); // チャンネル数
      view.setUint32(24, sampleRate, true); // サンプリングレート
      view.setUint32(28, sampleRate * 2, true); // データ速度
      view.setUint16(32, 2, true); // ブロックサイズ
      view.setUint16(34, 16, true); // サンプルあたりのビット数
      writeString(view, 36, 'data'); // dataチャンク
      view.setUint32(40, samples.length * 2, true); // 波形データのバイト数
      floatTo16BitPCM(view, 44, samples); // 波形データ

      return view;
    },
    // 溜めたデータを一次元に直す(wav化用)
    mergeBuffers(audioData) {
      let sampleLength = 0;
      for (let i = 0; i < audioData.length; i++) {
        sampleLength += audioData[i].length;
      }
      const samples = new Float32Array(sampleLength);
      let sampleIdx = 0;
      for (let i = 0; i < audioData.length; i++) {
        for (let j = 0; j < audioData[i].length; j++) {
          samples[sampleIdx] = audioData[i][j];
          sampleIdx++;
        }
      }
      return samples;
    },
    // 指定の秒数で切り取る(wav化用)
    cutSamples(samples,stSecond,finSecond){
      if(!stSecond || !finSecond){
        return samples
      }
      const lag = 0
      stSecond = stSecond - lag>0? stSecond - lag :0
      finSecond = finSecond - lag>0? finSecond - lag :finSecond-stSecond
      const st = stSecond * sampleRate
      const fin = finSecond * sampleRate
      let targetSamples = samples.slice(st,fin)
      
      if(targetSamples.length == 0){
        throw 'Error: samples lengh is 0'
      }
      if(targetSamples.length <= 4 * sampleRate){
        // 4秒未満の時は増やす
        const n = Math.ceil(10*sampleRate/targetSamples.length)
        const baseSamples = targetSamples
        targetSamples = new Float32Array(baseSamples.length * n)
        for(let i=0; i < n ;i++){
          targetSamples.set(baseSamples,baseSamples.length*i)
        }
      }else if(targetSamples.length >= 120 * sampleRate){
        // 120秒以上の時は削る
        targetSamples = targetSamples.slice(0,120*sampleRate)
      }
      return targetSamples
    },
    // 一番下までスクロールする
    scroll(){
      const container = this.$el.querySelector(".b-table-sticky-header");
      container.scrollTop = container.scrollHeight;
    },
  }
}

// デバイスとして使えるものの探査
// let audioLists = []
// let videoLists = []
// let audiooutLists = []

// function getLocalDevices () {
//   navigator.mediaDevices.enumerateDevices()
//     .then(deviceInfos => {
//       const audios = [{ text: '指定なし', value: '' }]
//       const videos = [{ text: '指定なし', value: '' }]
//       const audioouts = [{ text: '指定なし', value: '' }]
//       for (let i = 0; i < deviceInfos.length; i++) {
//         const deviceInfo = deviceInfos[i]
//         if (deviceInfo.kind === 'audioinput') {
//           audios.push({
//             text: deviceInfo.label || `Microphone ${audios.length + 1}`,
//             value: deviceInfo.deviceId
//           })
//         } else if (deviceInfo.kind === 'videoinput') {
//           videos.push({
//             text: deviceInfo.label || `Camera  ${videos.length + 1}`,
//             value: deviceInfo.deviceId
//           })
//         } else if (deviceInfo.kind === 'audiooutput') {
//           audioouts.push({
//             text: deviceInfo.label || `Camera  ${videos.length + 1}`,
//             value: deviceInfo.deviceId
//           })
//         }
//       }
//       audioLists = audios
//       videoLists = videos
//       audiooutLists = audioouts
//     })
// }



</script>
