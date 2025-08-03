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

// Tự động cập nhật luật chơi trên giao diện
ruleLosingEl.textContent = `Luật chơi: Cộng dồn số lượt đi. Ai đạt đến ${losingNumber} trước sẽ thua!`;
ruleWinningEl.textContent = `Mục tiêu: Đạt được ${winningNumber} để thắng.`;

function playerMove(move) {
  updateNumber(move, "Bạn");
  if (currentNumber >= losingNumber) {
    endGame("Bạn");
    return;
  }
  // Máy tính chơi sau một khoảng trễ nhỏ
  setTimeout(computerMove, 500);
}

function computerMove() {
  // AI thông minh hơn: Mục tiêu là di chuyển đến một số `N` sao cho `N % 4` bằng 3.
  // Theo luật chơi này (ai đến 20 thua), các số 3, 7, 11, 15, 19 là các vị trí "thua"
  // cho người chơi nào phải đi từ các số đó. Máy tính sẽ cố gắng đưa bạn vào các vị trí này.
  let move = 0;

  // Thử tìm một nước đi (1, 2, hoặc 3) để đưa tổng số về dạng `4k + 3`
  for (let i = 1; i <= 3; i++) {
    if ((currentNumber + i) % 4 === 3) {
      move = i;
      break;
    }
  }

  // Nếu không có nước đi nào như vậy (nghĩa là số hiện tại đã là `4k + 3`),
  // máy tính đang ở thế bất lợi. Nó sẽ đi một nước ngẫu nhiên và hy vọng người chơi mắc sai lầm.
  if (move === 0) {
    move = Math.floor(Math.random() * 3) + 1;
  }

  // Logic này đảm bảo máy sẽ luôn thực hiện nước đi tối ưu để thắng
  // hoặc kéo dài trò chơi nếu đang ở thế thua.
  // Ví dụ: nếu số hiện tại là 18, máy sẽ đi +1 để thành 19 (vì 19 % 4 == 3).
  // Nếu số hiện tại là 19, máy không tìm được nước đi tối ưu (move=0),
  // nên sẽ đi ngẫu nhiên và thua.

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
