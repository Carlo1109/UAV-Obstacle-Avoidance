clear
close all 
clc

% Use global Parameters to simplify simulation
global A B K Kp Kd mu d d1 f Ox Oy R Obs alpha 

global Pd Xd Yd Zd Pd_dot Xd_dot Yd_dot Zd_dot Pd_dd s r a b Ox Oy Oz Ux Uy Uz Ob1 Ob2 H
syms Pd Xd Yd Zd Pd_dot Xd_dot Yd_dot Zd_dot Pd_dd s

%% Trajectory Parameters (for feedforward)
% Origin
Ox = 10;
Oy = 3;
Oz = 20;

% Ellipse's axes
a = 20;
b = 10;

% Angular velocity (in Rad/s)
f = pi/4;

%% Feedforward (elliptic trajectory)

% Trajectory Reference
Pd = [  Ox - f*s; Oy; Oz];

% First derivative (velocity reference)
Pd_dot  = [ -f; 0; 0];

Xd_dot = Pd_dot(1,:);
Yd_dot = Pd_dot(2,:);
Zd_dot = Pd_dot(3,:);

% Second derivative (acceleration reference for feedforward term)
Pd_dd = [0; 0; 0];

%% Obstacles Coordinates

% In this scenario, all obstacles are moving. Otherwise, specify constant
% Position of each obstacle

%% Controller's parameters 
% Proportional And derivative Gains
Kp = 100;
Kd = 30;

% Gain Matrix
K = [   Kp  0   0   Kd  0   0;
        0   Kp  0   0   Kd  0
        0   0   Kp  0   0   Kd];

% CBF Parameters
alpha = 5;
mu = 0.05;
d = 2;
d1 = 5;
r = 1;

% Controller saturation
sat = 20;

%% System Dynamics' Matrices

A = [   0 0 0 1 0 0;
        0 0 0 0 1 0;
        0 0 0 0 0 1;
        0 0 0 0 0 0;
        0 0 0 0 0 0; 
        0 0 0 0 0 0];


B = [   0 0 0;
        0 0 0;
        0 0 0;
        1 0 0;
        0 1 0;
        0 0 1];

%% Closed Loop system simulation

% Initial state (robot in the origin, with zero velocity)
x0 = [10 3 20 0 0 0];

% Simulation time vector
tspan=0:0.05:30;

% Start simulation
[t, x]=ode45(@simulation,tspan,x0);

% Convert data format for plotting
[~,Xd,Yd,Zd, Ux, Uy, Uz, Ob1, h] = cellfun(@(t,x) simulation(t,x.'), num2cell(t), num2cell(x,2),'uni',0);
H = cell2mat(h)

%Extracting positions of Obstacle
Pobs1x = zeros(1, length(Ob1));
Pobs1y = zeros(1, length(Ob1));
Pobs1z = zeros(1, length(Ob1));

for i = 1:length(Ob1)
    Px = Ob1{i}(1,:);
    Py = Ob1{i}(2,:);
    Pz = Ob1{i}(3,:);
    Pobs1x(i) = double(Px);
    Pobs1y(i) = double(Py);
    Pobs1z(i) = double(Pz);
end

%% Plotting

% Robot Trajectory
figure(1)
title('Robot Trajectory')
xlabel('x')
ylabel('y')

% X,Y position
X = x(:,1);
Y = x(:,2);
Z = x(:,3);

% X,Y velocities
X_dot = x(:,4);
Y_dot = x(:,5);
Z_dot = x(:,6);

% Plot robot trajectory
plot3(X,Y,Z,'color', 'b', 'LineWidth', 2)
xlim([-15,15]);
ylim([-15,15]);
zlim([-15,15]);

hold on



% Plot Obstacles
for i=1:size(Obs,2)

    cx = Obs(1,i);
    cy = Obs(2,i);
    cz = Obs(3,i);
    
    [x, y, z] = sphere(50);

    Xeff = d*x +cx;
    Yeff = d*y +cy;
    Zeff = d*z +cz;

    surf(Xeff, Yeff, Zeff, 'FaceColor', 'r', 'EdgeColor','none');

    plot3(cx,cy, cz, 'bo', 'LineWidth', 5);
end


% Plot Reference Trajectory
xd = cell2mat(Xd);
yd = cell2mat(Yd);
zd = cell2mat(Zd);

plot3(xd, yd, zd, 'color', 'b', 'LineWidth', 2)


% Extract robot's "trail"
%[X1, X2, Y1, Y2, Z1, Z2] = border(X,Y,Z,X_dot, Y_dot,Z_dot);

% Plot the two curves that define the trail
% plot3(X1, Y1, Z1, 'b', 'LineWidth', 1);
% plot3(X2, Y2, Z2, 'b', 'LineWidth', 1);

% Fill area in between
% for i=2:length(X1)
%     plot3([X1(i) X2(i)], [Y1(i) Y2(i)], [Z1(i) Z2(i)], 'b', 'LineWidth', 0.1)
% end

% Control Effort
figure(2)
title('Control Effort')
xlabel('t')
ylabel('u(t) [m/s^2]')
ux = cell2mat(Ux);
uy = cell2mat(Uy);
uz = cell2mat(Uz);
plot(t,ux, 'b',t, uy,'r', t, uz, 'y', 'LineWidth',2)
yline(sat, 'k--','Label','Saturation')
yline(-sat, 'k--','Label','Saturation')
legend('x acceleration','y acceleration', 'z acceleration')
% ylim([min([ux;uy])-2,max([ux;uy])+2])

% Robot Velocity
figure(3)
title('Robot Velocities')
xlabel('t')
ylabel('v(t) [m/s]')
plot(t,X_dot, 'b',t, Y_dot,'r','LineWidth',2)
legend('x velocity','y velocity')
ylim([min([X_dot;Y_dot])-2,max([X_dot;Y_dot])+2])

%% Simulation Function
function [dx,Xd,Yd,Zd, Ux, Uy, Uz, Ob1, h] =simulation(t,x)
global A B Pd Pd_dot Pd_dd s Kp Kd Obs mu alpha r a b f Ox Oy Oz po poPerp

deltaFunc1 = 2;

% FeedForward
yref = [Ox - f*t; Oy; Oz];

yref_dot  = [-f; 0; 0];

yref_dd = [0; 0; 0];

yref = double(yref);
yref_dot = double(yref_dot);
yref_dd = double(yref_dd);

% Obstacle Position (moving)
% Ob1 = [   -0.5*f*t  ;
%         10 - f*t  ];
% 
% Ob1Dot = [-0.5*f; -f];

Ob1 = [f*t; 3; 20];
Ob1Dot = [f; 0; 0];

Ob1DotDot = [0; 0; 0];

Ob1 = double(Ob1);
Ob1Dot = double(Ob1Dot);
Ob1DotDot = double(Ob1DotDot);

Obs = Ob1;
% Position and Velocity
Pi = x(1:3);
Pi_dot = x(4:6);

% Nominal control
uNominal = yref_dd + Kd*(yref_dot - Pi_dot) + Kp*(yref-Pi);

t

V = (Pi- Ob1);
if(norm(V)<=r+deltaFunc1)
    disp(norm(V))
end
V_dot = (Pi_dot - Ob1Dot);
%Definition of Projection Operators
po = V*((V'*V)^(-1))*V';
poPerp = eye(3) - po;

u_perp = 0;
% Perp component
if rank([V, Pi_dot, Ob1Dot],  0.1) == 1
    u_perp = ([-V(2); V(1); 0]);
end
    

V_inv = V*((V'*V)^(-1));
%Definition of CBF
h1 = V' * (mu*uNominal + 2*V_dot - mu*Ob1DotDot);
h2 = (V'*V + mu*V'*V_dot);
gamma = 12;

%Switching
if h1>0 || h2>deltaFunc1+(r*gamma)
    u = uNominal;
else
    u = ((-2/mu)*(po*V_dot)) + (poPerp*uNominal) + Ob1DotDot + u_perp; %+ 2*V_inv*Pi_dot'*Ob1Dot;
end

% % Compute distances from obstacles
% len = length(Obs);
% dist = zeros(1, len);
% for i=1:len
% dist(1,i) = (Obs(:,i) - Pi)'*(Obs(:,i) - Pi);
% end

% % Find closest Obstacle
% [~, index] = min(dist);
% Pobs = Obs(:, index);
% dist(index) = inf;

% % Find second closest Obstacle
% [~, ind] = min(dist);
% Pobs2 = Obs(:, ind);
% 
% % Distance from closest Obstacle
% z = Pi - Pobs;
% 
% % Distance between the two closest obstacles
% l = sqrt((Pobs2 - Pobs)'*(Pobs2 - Pobs));
% 
% % If robot can't fit between the two closest obstacles, consider a
% % single obstacle that "covers" the two
% if sqrt(z'*z) < l+d + 2*r && l <= 2*(r + d)
%     Pobs = (Pobs2 + Pobs)/2;
%     d = 2*(l/2+d+r);
%     z = Pi - Pobs ;
% end
% 
% % Quadratic Programming optimization
% Q = eye(2);
% E = mu*z';
% L = (2+alpha*mu)*(z'*Pi_dot) + mu*(Pi_dot'*Pi_dot) + alpha*(z'*z-r^2) - 8*alpha*(d+r);% + (z'*Pi_dot)/((Pobs-Pobs2)'*Pi_dot+r);
% 
% options = optimset('Display', 'off');
% u = quadprog(Q, -2*U_nom, -E,L,[],[],[],[],[], options) ;

% % Controller Saturation (if needed)
% sat = 20;
% 
% if u(1) > sat
%     u(1) = sat;
% end
% 
% if u(1) < -sat
%     u(1) = -sat;
% end
% 
% if u(2) > sat
%     u(2) = sat;
% end
% 
% if u(2) < -sat
%     u(2) = -sat;
% end

% X,Y control
Ux = u(1);
Uy = u(2);
Uz = u(3);

% X,Y reference 
Xd = yref(1);
Yd = yref(2);
Zd = yref(3);

% CBF evaluation index
h = V'*V+mu*V'*V_dot - (deltaFunc1+r);

% Proceed to next simulation step
dx = A*x + B*u;
end

%% Trail generator function
% Compute trail based on robot velocities and position, given it's radius
% function [X1, X2, Y1, Y2, Z1, Z2]=border(X, Y, Z, X_dot, Y_dot, Z_dot)
%     global r
%     n = length(X);
%     x1 = zeros(n,1);
%     y1 = zeros(n,1);
%     z1 = zeros(n,1);
% 
%     x2 = zeros(n,1);
%     y2 = zeros(n,1);
%     z2 = zeros(n,1);
% 
% 
%     for i=2:n
%     d = sqrt(X_dot(i)^2+Y_dot(i)^2+Z_dot(i)^2);
%     sin_a = Y_dot(i)/d;
%     cos_a = X_dot(i)/d;
% 
%     x1(i) = X(i)-r*sin_a;
%     y1(i) = Y(i)+r*cos_a;
% 
%     x2(i) = X(i)+r*sin_a;
%     y2(i) = Y(i)-r*cos_a;
%     end
%     X1 = x1;
%     Y1 = y1;
%     X2 = x2;
%     Y2 = y2;
% end