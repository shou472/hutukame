<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>お楽しみ抽選会</title>
    <style>
        body {
            font-family: 'Helvetica Neue', Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f7f9fc;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            text-align: center;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            max-width: 90%;
            width: 400px;
            position: relative;
        }
        h1 { color: #333; margin-bottom: 20px; font-size: 24px; }
        .qr-placeholder {
            width: 200px;
            height: 200px;
            background: #eee;
            margin: 20px auto;
            display: flex;
            justify-content: center;
            align-items: center;
            border: 4px solid #333;
            font-weight: bold;
            font-size: 14px;
        }
        .result-box { display: none; }
        .rank { font-size: 36px; font-weight: bold; color: #ff4757; margin-bottom: 15px; animation: pop 0.5s ease; }
        .prize { font-size: 28px; font-weight: bold; color: #2f3542; margin-bottom: 25px; }
        .timer { color: #747d8c; font-size: 14px; background: #f1f2f6; padding: 10px; border-radius: 10px; }
        
        @keyframes pop {
            0% { transform: scale(0.5); opacity: 0; }
            100% { transform: scale(1); opacity: 1; }
        }

        /* 設定ボタンとモーダル */
        .settings-btn {
            position: absolute;
            top: 15px;
            right: 15px;
            background: none;
            border: none;
            color: #a4b0be;
            cursor: pointer;
            font-size: 14px;
            text-decoration: underline;
        }
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            justify-content: center;
            align-items: center;
            z-index: 100;
        }
        .modal-content {
            background: white;
            padding: 25px;
            border-radius: 15px;
            width: 320px;
            max-width: 90%;
            text-align: left;
            max-height: 90vh;
            overflow-y: auto;
        }
        .modal-content h3 { margin-top: 0; border-bottom: 2px solid #f1f2f6; padding-bottom: 8px; font-size: 18px; color: #2f3542; }
        .setting-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 15px; }
        .setting-row input { width: 65px; padding: 6px; font-size: 16px; text-align: right; border: 1px solid #ccc; border-radius: 5px; }
        .total-prob { text-align: right; font-weight: bold; margin-bottom: 15px; font-size: 15px; }
        .count-item { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 15px; background: #f8f9fa; padding: 8px 12px; border-radius: 6px; }
        
        .btn-group { display: flex; justify-content: space-between; margin-top: 20px; gap: 10px; }
        .save-btn { background: #2ed573; color: white; border: none; padding: 10px 15px; border-radius: 6px; cursor: pointer; font-weight: bold; flex: 1; }
        .close-btn { background: #747d8c; color: white; border: none; padding: 10px 15px; border-radius: 6px; cursor: pointer; }
        .reset-btn { background: #ff4757; color: white; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; font-size: 13px; width: 100%; margin-top: 10px; }
    </style>
</head>
<body>

<div class="container">
    <button class="settings-btn" onclick="openSettings()">設定</button>

    <!-- 初期QR案内画面 -->
    <div id="qr-screen">
        <h1>次の方どうぞ！</h1>
        <div class="qr-placeholder">
            <span style="padding: 10px;">QRコードを<br>スキャンしてください</span>
        </div>
        <p style="color:#57606f; margin-bottom:20px;">スマホで読み込むと、結果が表示されます！</p>
    </div>

    <!-- 結果表示画面 -->
    <div id="result-screen" class="result-box">
        <h1>抽選結果</h1>
        <div id="result-rank" class="rank">一等 🎉</div>
        <div id="result-prize" class="prize">明和町カレー</div>
        <div id="result-timer" class="timer">10秒後に画面が戻ります</div>
    </div>
</div>

<!-- 設定モーダル -->
<div id="settings-modal" class="modal">
    <div class="modal-content">
        <h3>⚙️ 出現確率の設定 (合計100%)</h3>
        <div class="setting-row">
            <span>一等 (カレー/柿の種):</span>
            <div><input type="number" id="prob-1" min="0" max="100" oninput="calcTotal()"> %</div>
        </div>
        <div class="setting-row">
            <span>二等 (なしのしずく):</span>
            <div><input type="number" id="prob-2" min="0" max="100" oninput="calcTotal()"> %</div>
        </div>
        <div class="setting-row">
            <span>三等 (うまい棒):</span>
            <div><input type="number" id="prob-3" min="0" max="100" oninput="calcTotal()"> %</div>
        </div>
        <div class="total-prob" id="prob-total-display">合計: 100%</div>

        <h3 style="margin-top: 20px;">📊 出た数（当選カウント）</h3>
        <div class="count-item"><span>一等 明和町カレー:</span> <strong><span id="count-curry">0</span> 個</strong></div>
        <div class="count-item"><span>一等 柿の種:</span> <strong><span id="count-kaki">0</span> 個</strong></div>
        <div class="count-item"><span>二等 なしのしずく:</span> <strong><span id="count-pear">0</span> 本</strong></div>
        <div class="count-item"><span>三等 うまい棒:</span> <strong><span id="count-umai">0</span> 個</strong></div>
        <button class="reset-btn" onclick="resetCounts()">出た数のカウントを0にリセット</button>

        <div class="btn-group">
            <button class="close-btn" onclick="closeSettings()">閉じる</button>
            <button class="save-btn" onclick="saveSettings()">確率を保存</button>
        </div>
    </div>
</div>

<script>
    // 初期設定データ（確率合計100%）
    const DEFAULT_PROBS = { p1: 20, p2: 30, p3: 50 };
    const DEFAULT_COUNTS = { curry: 0, kaki: 0, pear: 0, umai: 0 };

    let probs = JSON.parse(localStorage.getItem('custom_lottery_probs')) || { ...DEFAULT_PROBS };
    let counts = JSON.parse(localStorage.getItem('custom_lottery_counts')) || { ...DEFAULT_COUNTS };
    
    let returnTimeout;
    let countdownInterval;

    // 画面の数値更新
    function updateDisplay() {
        document.getElementById('prob-1').value = probs.p1;
        document.getElementById('prob-2').value = probs.p2;
        document.getElementById('prob-3').value = probs.p3;
        calcTotal();

        document.getElementById('count-curry').innerText = counts.curry;
        document.getElementById('count-kaki').innerText = counts.kaki;
        document.getElementById('count-pear').innerText = counts.pear;
        document.getElementById('count-umai').innerText = counts.umai;
    }

    // 合計パーセントのリアルタイム計算
    function calcTotal() {
        let v1 = Number(document.getElementById('prob-1').value) || 0;
        let v2 = Number(document.getElementById('prob-2').value) || 0;
        let v3 = Number(document.getElementById('prob-3').value) || 0;
        let total = v1 + v2 + v3;
        
        let totalEl = document.getElementById('prob-total-display');
        totalEl.innerText = `合計: ${total}%`;
        totalEl.style.color = (total === 100) ? '#2ed573' : '#ff4757';
    }

    // 設定ボタン押下時（パスワード認証）
    function openSettings() {
        let pass = prompt("設定パスワード（半角数字4桁）を入力してください:");
        if (pass === "0000") {
            updateDisplay();
            document.getElementById('settings-modal').style.display = 'flex';
        } else if (pass !== null) {
            alert("パスワードが違います。");
        }
    }

    function closeSettings() {
        document.getElementById('settings-modal').style.display = 'none';
    }

    // 確率の保存
    function saveSettings() {
        let v1 = Number(document.getElementById('prob-1').value) || 0;
        let v2 = Number(document.getElementById('prob-2').value) || 0;
        let v3 = Number(document.getElementById('prob-3').value) || 0;

        if (v1 + v2 + v3 !== 100) {
            alert(`確率の合計が ${v1 + v2 + v3}% になっています。\n合計がぴったり 100% になるように調整してください！`);
            return;
        }

        probs = { p1: v1, p2: v2, p3: v3 };
        localStorage.setItem('custom_lottery_probs', JSON.stringify(probs));
        alert("新しい出現確率を保存しました！");
        closeSettings();
    }

    // カウントのリセット
    function resetCounts() {
        if (confirm("これまでに出た数のカウントをすべて 0 に戻しますか？")) {
            counts = { ...DEFAULT_COUNTS };
            localStorage.setItem('custom_lottery_counts', JSON.stringify(counts));
            updateDisplay();
        }
    }

    // ページ読み込み時に即抽選
    window.onload = function() {
        drawLottery();
    };

    function drawLottery() {
        let rand = Math.random() * 100; // 0 〜 99.99...
        let rank = "";
        let prize = "";

        if (rand < probs.p1) {
            // 一等当選
            rank = "一等 🎉";
            // カレーか柿の種を半分(50%)の確率で抽選
            if (Math.random() < 0.5) {
                prize = "明和町カレー";
                counts.curry++;
            } else {
                prize = "柿の種";
                counts.kaki++;
            }
        } else if (rand < (probs.p1 + probs.p2)) {
            // 二等当選
            rank = "二等 ✨";
            prize = "なしのしずく";
            counts.pear++;
        } else {
            // 三等当選
            rank = "三等 📢";
            prize = "うまい棒";
            counts.umai++;
        }

        // 出た数を保存
        localStorage.setItem('custom_lottery_counts', JSON.stringify(counts));

        // 結果画面を表示
        document.getElementById('result-rank').innerText = rank;
        document.getElementById('result-prize').innerText = prize;
document.getElementById('qr-screen').style.display = 'none';
document.getElementById('result-screen').style.display = 'block';
// 10秒カウントダウンと自動リターン
let timeLeft = 10;
document.getElementById('result-timer').innerText = ⚠️ ${timeLeft}秒後に画面が戻ります;
clearInterval(countdownInterval);
countdownInterval = setInterval(() => {
timeLeft--;
if (timeLeft > 0) {
document.getElementById('result-timer').innerText = ⚠️ ${timeLeft}秒後に画面が戻ります;
} else {
clearInterval(countdownInterval);
}
}, 1000);
clearTimeout(returnTimeout);
returnTimeout = setTimeout(() => {
backToQR();
}, 10000);
}
function backToQR() {
document.getElementById('result-screen').style.display = 'none';
document.getElementById('qr-screen').style.display = 'block';
}
