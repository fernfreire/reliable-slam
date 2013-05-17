funcprot(0);
clear;

// Number of particles
K_param=100; 

// Number of landmarks
N_param=2;

// Degrees to radians
deg2rad=%pi/180;

// Variance of the heading sensor
Ch=(0.02*deg2rad)^2;

// Covariance of the motion noise
Mt=[0.04^2 0;
0 (0.01*deg2rad)^2];

// Variance of the range sensor
Cr=0.3^2;

// 1 particle is 
// [[w(1:t)] [x_1:t] [y_1:t] [theta_1:t] [mux_l1_1:t] [muy_l1_1:t]  ... [mux_lN_1:t] [muy_lN_1:t] [sigmaxx_l1_1:t] [sigmaxy_l1_1:t] [sigmayx_l1_1:t] [sigmayy_l1_1:t] ... [sigmaxx_lN_1:t] [sigmaxy_lN_1:t] [sigmayx_lN_1:t] [sigmayy_lN_1:t]]
// w=weight
// Particle array (memory)
// It has 3-dimension (time t of the particle, member index of the particle members, index of the particle {k})
P=[];

// Initialize a particle-set according to the given "a-priori" initial state-vector,
// uniformely distributed in boxes for the robot pose,
// normally distributed for the landmarks position
// init_vector is [w x y theta l1_x l1_y l2_x l2_y...sigma...]
// pose_uncertainty contains the half-width of the pose boxes
function [Y]=init_particle_set(K,N,init_vector,pose_uncertainty)
    Y=zeros(1,4+(2+4)*N,K);
    low=init_vector(2:4)-pose_uncertainty(1:3);
    high=init_vector(2:4)+pose_uncertainty(1:3);
    Y(1,1,1:K)=1/K; // initialize weights
    
    for i=1:K,
        for j=1:3, // pose & orientation uncertainty
            Y(1,j+1,i)=grand(1,1,'unf',low(j),high(j));
        end
        for j=1:N, // landmarks uncertainty
            Y(1,4+2*(j-1):4+2*(j-1)+1,i)=grand(1,'mn',get_landmark_estimate(init_vector,j),get_landmark_covariance(init_vector,j))';
        end
    end
endfunction

// Get the estimate position of the ith landmark
function [L_pose]=get_landmark_estimate(particle,i)
    L_pose=[particle(1,4+1+(i-1)*2);
    particle(1,4+1+(i-1)*2+1)];
endfunction

// Get the covariance matrix of the ith landmark
function [Sigma]=get_landmark_covariance(particle,i)
    Sigma=[particle(1,4+1+N*2+(i-1)*4:4+1+N*2+(i-1)*4+1);
    particle(1,4+1+N*2+(i-1)*4+2:4+1+N*2+(i-1)*4+3)];
endfunction

// Observation function
function [z_hat]=h(mu,x) // TODO: use the particle as input+ make it landmark nb independant
    return [sqrt((mu(1)-x(1))^2+(mu(2)-x(2))^2);
    sqrt((mu(3)-x(1))^2+(mu(4)-x(2))^2);
    sqrt((mu(5)-x(1))^2+(mu(6)-x(2))^2)];
endfunction

// Returns the jacobian of the observation function
function [C]=jacobian_observation(particle,N)
    C=[];
    for i=1:N,
        C=[C;] // TODO
    end
endfunction

// FastSLAM 1.0 algorithm with known correspondances landmarks
function [Y_pos]=fast_slam_1(z, u, Y_prev,dt,t)
    for k=1:K,
        particle=Y_prev(1+(k-1)*(4+N*6):1+k*(4+N*6));
        particle(2:4)=sample_motion_model(particle(2:4),u,dt); // sample pose
        z_hat=h(particle(5:5+2*N),particle(2:4)); // measurement prediction
        
        // Jacobian of the observation matrix (3 landmarks)
        C=[(mut(1)-mut(4))/y(2) (mut(2)-mut(5))/y(2) 0 (mut(4)-mut(1))/y(2) (mut(5)-mut(2))/y(2) 0 0;
        (mut(1)-mut(6))/y(3) (mut(2)-mut(7))/y(3) 0 0 0 (mut(6)-mut(1))/y(3) (mut(7)-mut(2))/y(3)];
    end
endfunction

function [x]=sample_motion_model(x_prev,u,dt)
    u=u+grand(1,'mn',zeros(2,1),Mt); // Add noise to the control input
    x=x_prev+[u(1)*dt*cos(x_prev(3));
    u(1)*dt*sin(x_prev(3));
    dt*u(2)+grand(1,1,'nor',0,Ch)];
endfunction

function [Y]=resampling_roulette()
    
endfunction

function [Y]=resampling_low_variance()
    
endfunction

function [pos,landmarks]=plot_set(Y)
    pos=[];
    landmarks=[];
    for i=1:size(Y,3),
        pos=[pos;Y(1,2,i) Y(1,3,i)]
        landmarks=[landmarks; Y(1,4:4+2*N_param+1,i)];
    end
    xpoly(pos(:,1),pos(:,2),"marks");
    handle=gce();
    handle.line_mode="off";
    handle.mark_size=0;
    handle.mark_mode="on";
    handle.mark_style=0;
    handle.mark_foreground=color('red');
    
    xpoly(landmarks(:,1),landmarks(:,2));
    handle_l=gce();
    handle_l.line_mode="off",
    handle_l.mark_size=0;
    handle_l.mark_mode="on";
    handle_l.mark_style=14;
    handle_l.mark_foreground=color('blue');
    
    xpoly(landmarks(:,3),landmarks(:,4));
    handle_l2=gce();
    handle_l2.line_mode="off",
    handle_l2.mark_size=0;
    handle_l2.mark_mode="on";
    handle_l2.mark_style=14;
    handle_l2.mark_foreground=color('orange');
endfunction

[p_set]=init_particle_set(K_param,N_param,[0 0 0 0 -10 4 10 25 1 0 0 1 1 0 0 1],[1 1 1]);
figure(1);
drawlater();
h_axes = gca();
h_axes.data_bounds = [-25,-45;25,35];
[pos,landmarks]=plot_set(p_set);
drawnow();