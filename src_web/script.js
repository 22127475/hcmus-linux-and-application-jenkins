const MAX_NUMBER = 30;

let currentNumber = 0;
const winningNumber = MAX_NUMBER - 1;
const losingNumber = MAX_NUMBER;

const currentNumberEl = document.getElementById("current-number");
const gameStatusEl = document.getElementById("game-status");
const restartButtonEl = document.getElementById("restart-button");
const playerButtons = document.querySelectorAll("#player-controls button");
const ruleLosingEl = document.getElementById("rule-losing");
const ruleWinningEl = document.getElementById("rule-winning");

ruleLosingEl.textContent = `Luật chơi: Cộng dồn số lượt đi. Ai đạt đến ${losingNumber} trước sẽ thua!`;
ruleWinningEl.textContent = `Mục tiêu: Đạt được ${winningNumber} để thắng.`;

function playerMove(move) {
  updateNumber(move, "Bạn");
  if (currentNumber >= losingNumber) {
    endGame("Bạn");
    return;
  }
  setTimeout(computerMove, 500);
}

function computerMove() {
  let move = 0;

  for (let i = 1; i <= 3; i++) {
    if ((currentNumber + i) % 4 === 3) {
      move = i;
      break;
    }
  }

  
  if (move === 0) {
    move = Math.floor(Math.random() * 3) + 1;
  }

  updateNumber(move, "Máy");
  if (currentNumber >= losingNumber) {
    endGame("Máy");
  }
}

function updateNumber(move, player) {
  currentNumber += move;
  currentNumberEl.textContent = currentNumber;
  gameStatusEl.textContent = `${player} đã cộng ${move}`;
}

function endGame(player) {
  if (player === "Bạn") {
    gameStatusEl.textContent = `Bạn đã đạt đến ${currentNumber}. Bạn thua!`;
  } else {
    gameStatusEl.textContent = `Máy đã đạt đến ${currentNumber}. Bạn thắng!`;
  }
  toggleButtons(true);
}

function restartGame() {
  currentNumber = 0;
  currentNumberEl.textContent = currentNumber;
  gameStatusEl.textContent = "";
  toggleButtons(false);
}

function toggleButtons(disabled) {
  playerButtons.forEach((button) => {
    button.disabled = disabled;
  });
  restartButtonEl.style.display = disabled ? "inline-block" : "none";
}
