## Inspiration

"Beauty" is rather abstract, so we were interested in finding a way to use mathematics to describe it in a consistent and quantifiable way.

We also wanted to question whether "Beauty" is an objective or subjective reality. It may be a bit of both, as it turns out.

## What it does

Sigma scans the users' face, infers their "Face Mesh," then computes a final rating based on facial geometry and common beauty signals. We also allow an LLM to comment on the image, providing commentary on the user's aesthetic.

Their final score is calculated based on the following components, extrapolated from the face mesh:

- Facial Symmetry ($S{sym}$) Reflects the left eye outer corner ($P{L}$) across the midline established by the nose bridge to find a predicted mirror point ($P'{R}$), then normalized by face width ($W{face}$). $$S{sym} = \text{clamp}\left( 100 \times \left( 1 - 4 \times \frac{ | P{R} - P'{R} | }{ W{face} } \right), 0, 100 \right)$$

- Horizontal Golden Ratio ($GR$) The ratio between total face width and the span between the outer corners of both eyes. $$GR = \frac{W{face}}{W{outer_eye_span}} \quad (\text{Ideal } \phi \approx 1.618)$$

- Facial Thirds Ratio ($T$) Calculated using vertical $y$-axis differences between the hairline ($H$), nasion ($N$), subnasale ($Sn$), and menton ($M$). $$T{upper} = |y_N - yH|, \quad T{mid} = |y_{S_n} - yN|, \quad T{lower} = |yM - y{Sn}|$$ $$\text{Ratio} = \frac{T{upper}}{T{min}} : \frac{T{mid}}{T{min}} : \frac{T{lower}}{T_{min}}$$

- Canthal Tilt ($\theta$ in degrees) The average angle between the inner ($P{in}$) and outer ($P{out}$) corners of the eyes. $$\theta = \frac{1}{2} \sum_{i \in {L, R}} \left( \text{atan2}(\Delta y_i, \Delta x_i) \times \frac{180}{\pi} \right)$$

- Lip Volume Ratio ($R{lip}$) The ratio of the physical height of the lower lip versus the upper lip. $$R{lip} = \frac{h_{lowerlip}}{h{upper_lip}} \quad (\text{Ideal } \approx 1.6)$$

Finally, all components are weighted and the letter grade is assigned.

Clamp function:
$$\text{clamp}(x,a,b)=\min\left(b,\max(a,x)\right)$$

Using:
- p (overall symmetry)
- t (average canthal tilt)
- g (horizontal golden ratio)
- (u,m,l) (upper, mid, lower vertical proportions)
- (U,L) (upper, lower lip heights)

$$S_{sym}=\text{clamp}\left(\frac{p-60}{40}\cdot 20,\;0,\;20\right)$$

$$S_{cant}=\text{clamp}\left(20e^{-\frac{(t-4)^2}{18}},\;0,\;20\right)$$

$$S_{gold}=\text{clamp}\left(20-70\left|g-1.618\right|,\;0,\;20\right)$$

$$\mu=\frac{u+m+l}{3},\quad \sigma^2=\frac{(u-\mu)^2+(m-\mu)^2+(l-\mu)^2}{3},\quad S_{thirds}=\text{clamp}\left(20-200\sigma^2,\;0,\;20\right)$$

$$S_{lip}=
\begin{cases}
10, & U \le 0\\
\text{clamp}\left(20-25\left|\frac{L}{U}-1.6\right|,\;0,\;20\right), & U>0
\end{cases}$$

$$S_{total}=S_{sym}+S_{cant}+S_{gold}+S_{thirds}+S_{lip}$$

$$\text{Tier}=
\begin{cases}
S, & S_{total}\ge 82\\
A, & 68\le S_{total}<82\\
B, & 52\le S_{total}<68\\
C, & S_{total}<52
\end{cases}$$

When you're finished parsing your results, you can even send a Sigma formatted PDF to your friends and family.

## How we built it

- We started with a new Flutter iOS Application.
- We then set up the Face Mesh inferencing system using MediaPipe(TensorFlow Lite through C++ FII, fully on-device through iOS Neural Engine)
    - MobileNetV2-based module infers 468 facial landmarks, zero network calls
    - Aquired a list of 2D points in image-space; the vertices in the mesh
- We then wrote a custom rendering algorithm in Dart to construct and destruct the Face Mesh, overlayed on the live video stream, based on the model's real-time confidence score.
- Using said 2D point array, we ran multiple proprietary algorithms (as described above) to aquire Symmetry, Golden Ratio, Facial Thrids, Canthal Tilt, and Lip Volume
- From there, we sent the image to GPT-4o-mini, along with the facial metrics and structured prompt to get a meaningful assesment of the user's face.
- We built out the rest of the UI/UX in Flutter, filling in the gaps, and ensuring a modern and approachable experience for all users

## Challenges we ran into

- It was rather difficult to overlay the Face Mesh on a live video stream due to differing coordinate systems.
- The rendering engine posed challenges concerning geometry, specifically sorting triangles and connecting vertices correctly.
- Writing the algorithms to calculate face metrics was tedious as it required manually looking up Landmark IDs in MediaPipe's Face Mesh documentation.
- It was difficult to assign an objective scoring system through weighting face metrics. We shot around several ideas, and found that there wasn't a right answer that covered all cultures, body types, or genders.

## Accomplishments that we're proud of

- We created a full working application in less than two day's time.
- We think the application looks and feels premium, and tells a story for each user.
- Our face tracking pipeline is efficient and performs consistently well on both our devices.
- Our custom rendering of the face mesh (destruction and construction,) along with the haptic feedback, makes the process feel technologically advanced.

## What we learned

Beauty isn't just math.

## What's next for Sigma

We will continue to work on the algorithm to make it fair across multiple cultures, body types and genders. We also intend to collect feedback, so we can lay off or lean into certain features of the application.
